-- ============================================================================
-- MCQ Pro: Private Teacher-Student Chat Feature Migration
-- Version: 20261016_private_teacher_student_chat.sql
-- Description: Completely private chat between assigned teachers and students.
--              STRICT PRIVACY: Admin has ABSOLUTELY NO ACCESS to chat conversations,
--              messages, previews, or RPCs.
--
-- ABSOLUTE RESTRICTION COMPLIANCE:
-- This script DOES NOT touch, alter, migrate, truncate, or drop public.keep_alive.
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. CREATE TABLE: public.chat_conversations
CREATE TABLE IF NOT EXISTS public.chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_message_at TIMESTAMPTZ,
    last_message_text TEXT,
    last_message_sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT chat_conversations_unique_pair UNIQUE (student_id, teacher_id),
    CONSTRAINT chat_conversations_distinct_participants CHECK (student_id != teacher_id)
);

-- 3. CREATE TABLE: public.chat_messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL CHECK (char_length(trim(message_text)) > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ
);

-- 4. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_chat_conversations_student ON public.chat_conversations(student_id);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_teacher ON public.chat_conversations(teacher_id);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_last_msg ON public.chat_conversations(last_message_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_id ON public.chat_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_conv_created ON public.chat_messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON public.chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread ON public.chat_messages(conversation_id, sender_id, read_at) WHERE read_at IS NULL;

-- 5. AUTOMATIC TRIGGER: Update conversation last_message summary upon new message
CREATE OR REPLACE FUNCTION public.handle_new_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    UPDATE public.chat_conversations
    SET 
        last_message_at = NEW.created_at,
        last_message_text = NEW.message_text,
        last_message_sender_id = NEW.sender_id
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_chat_message_inserted ON public.chat_messages;
CREATE TRIGGER trg_on_chat_message_inserted
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_chat_message();

-- 6. SECURITY HELPER: Verify if teacher is assigned to student based on existing scope
-- Checks institution, academic year, standard, division, medium, and subject/group
CREATE OR REPLACE FUNCTION public.is_teacher_assigned_to_student(p_teacher_id UUID, p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, extensions
AS $$
DECLARE
    v_has_match BOOLEAN;
BEGIN
    -- Strict privacy boundary: Admin accounts can NEVER be participants in chat
    IF EXISTS (
        SELECT 1 FROM public.users 
        WHERE id IN (p_teacher_id, p_student_id) AND role = 'admin'
    ) THEN
        RETURN FALSE;
    END IF;

    -- Match teacher assignments with student enrollment / profile
    SELECT EXISTS (
        SELECT 1
        FROM public.teacher_assignments ta
        JOIN (
            SELECT 
                u.id AS student_id,
                COALESCE(se.institution, u.institution, 'Sharda Mandir') AS institution,
                COALESCE(se.standard, u.class::text, '11') AS standard,
                COALESCE(se.division, u.division, 'A') AS division,
                COALESCE(se.medium, u.medium, 'English') AS medium,
                COALESCE(se.student_group, u.student_group, '') AS student_group
            FROM public.users u
            LEFT JOIN public.student_enrollments se ON se.student_id = u.id
            WHERE u.id = p_student_id AND u.role = 'student'
        ) s ON (
            -- Institution compatibility (handles Tuition ACC vs Sharda Mandir)
            (
                (LOWER(ta.institution) LIKE '%acc%' AND LOWER(s.institution) LIKE '%acc%')
                OR LOWER(ta.institution) = LOWER(s.institution)
            )
            -- Standard compatibility
            AND ta.standard = s.standard
            -- Division compatibility
            AND (
                ta.division = 'ALL'
                OR UPPER(ta.division) = UPPER(s.division)
                OR (LOWER(ta.institution) LIKE '%acc%' AND LOWER(s.institution) LIKE '%acc%')
            )
            -- Medium compatibility
            AND (
                ta.medium IN ('Both', 'All')
                OR LOWER(ta.medium) = LOWER(s.medium)
            )
        )
        WHERE ta.teacher_id = p_teacher_id
          AND (
              -- Compulsory subjects (Physics, Chemistry) are for all science students
              LOWER(ta.subject) IN ('physics', 'physical', 'chemistry')
              OR (
                  -- Biology stream
                  LOWER(ta.subject) IN ('biology', 'bio')
                  AND (
                      s.student_group IS NULL
                      OR LOWER(s.student_group) IN ('', 'biology', 'bio', 'b', 'science')
                      OR LOWER(s.student_group) LIKE '%bio%'
                  )
              )
              OR (
                  -- Math stream
                  LOWER(ta.subject) IN ('math', 'maths', 'mathematics')
                  AND (
                      LOWER(s.student_group) IN ('math', 'maths', 'a')
                      OR LOWER(s.student_group) LIKE '%math%'
                  )
              )
              OR (
                  -- Any other explicitly assigned subject
                  LOWER(ta.subject) NOT IN ('physics', 'physical', 'chemistry', 'biology', 'bio', 'math', 'maths', 'mathematics')
              )
          )
    ) INTO v_has_match;

    RETURN COALESCE(v_has_match, false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_teacher_assigned_to_student(UUID, UUID) TO authenticated;

-- 7. ENABLE ROW-LEVEL SECURITY
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- 8. ROW-LEVEL SECURITY POLICIES: chat_conversations
-- NOTE: Admin role is EXPLICITLY DENIED access. Only the student participant
-- or the assigned teacher participant can access or manipulate conversation rows.

-- (a) SELECT Policy: Student or Teacher participant only (Admin strictly excluded)
DROP POLICY IF EXISTS "Conversations participant select policy" ON public.chat_conversations;
CREATE POLICY "Conversations participant select policy"
ON public.chat_conversations FOR SELECT
USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND (auth.uid() = student_id OR auth.uid() = teacher_id)
);

-- (b) INSERT Policy: Must be a participant and must be a valid teacher-student assignment
DROP POLICY IF EXISTS "Conversations participant insert policy" ON public.chat_conversations;
CREATE POLICY "Conversations participant insert policy"
ON public.chat_conversations FOR INSERT
WITH CHECK (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND (
        (auth.uid() = student_id AND (SELECT role FROM public.users WHERE id = student_id) = 'student')
        OR
        (auth.uid() = teacher_id AND (SELECT role FROM public.users WHERE id = teacher_id) = 'teacher')
    )
    AND public.is_teacher_assigned_to_student(teacher_id, student_id)
);

-- (c) UPDATE Policy: Participant update for summary metadata (Admin strictly excluded)
DROP POLICY IF EXISTS "Conversations participant update policy" ON public.chat_conversations;
CREATE POLICY "Conversations participant update policy"
ON public.chat_conversations FOR UPDATE
USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND (auth.uid() = student_id OR auth.uid() = teacher_id)
)
WITH CHECK (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND (auth.uid() = student_id OR auth.uid() = teacher_id)
);

-- (d) DELETE Policy: No deletion allowed (preserving audit trail of chat messages)
DROP POLICY IF EXISTS "Conversations no delete policy" ON public.chat_conversations;
CREATE POLICY "Conversations no delete policy"
ON public.chat_conversations FOR DELETE
USING (false);

-- 9. ROW-LEVEL SECURITY POLICIES: chat_messages
-- NOTE: Messages are private between student and teacher. Admin has NO ACCESS.

-- (a) SELECT Policy: Must be a participant of the parent conversation
DROP POLICY IF EXISTS "Messages participant select policy" ON public.chat_messages;
CREATE POLICY "Messages participant select policy"
ON public.chat_messages FOR SELECT
USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND EXISTS (
        SELECT 1 FROM public.chat_conversations c
        WHERE c.id = chat_messages.conversation_id
          AND (c.student_id = auth.uid() OR c.teacher_id = auth.uid())
    )
);

-- (b) INSERT Policy: Sender must be the authenticated user and a participant
DROP POLICY IF EXISTS "Messages participant insert policy" ON public.chat_messages;
CREATE POLICY "Messages participant insert policy"
ON public.chat_messages FOR INSERT
WITH CHECK (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND sender_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.chat_conversations c
        WHERE c.id = conversation_id
          AND (c.student_id = auth.uid() OR c.teacher_id = auth.uid())
    )
);

-- (c) UPDATE Policy: Only the RECIPIENT can update messages (to set read_at)
-- Sender can never mark their own messages as read; Admin has no access.
DROP POLICY IF EXISTS "Messages recipient update read_at policy" ON public.chat_messages;
CREATE POLICY "Messages recipient update read_at policy"
ON public.chat_messages FOR UPDATE
USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND sender_id != auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.chat_conversations c
        WHERE c.id = chat_messages.conversation_id
          AND (c.student_id = auth.uid() OR c.teacher_id = auth.uid())
    )
)
WITH CHECK (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND sender_id != auth.uid()
);

-- (d) DELETE Policy: Optional sender-only soft deletion or disabled
DROP POLICY IF EXISTS "Messages sender delete policy" ON public.chat_messages;
CREATE POLICY "Messages sender delete policy"
ON public.chat_messages FOR DELETE
USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin'
    AND sender_id = auth.uid()
);

-- 10. ENSURE STUDENTS CAN VIEW ACTIVE TEACHER PROFILES
-- Students need to view teacher names and emails to display assigned teachers.
DO $$
BEGIN
    DROP POLICY IF EXISTS "Students can view active teachers" ON public.users;
    CREATE POLICY "Students can view active teachers"
    ON public.users FOR SELECT
    USING (
        role = 'teacher' AND is_active = true
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Notice on users teacher select policy: %', SQLERRM;
END $$;

-- 11. RPC FUNCTION: get_student_assigned_teachers
-- Securely returns the list of teachers assigned to the currently authenticated student
CREATE OR REPLACE FUNCTION public.get_student_assigned_teachers()
RETURNS TABLE (
    teacher_id UUID,
    name TEXT,
    email TEXT,
    subjects TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, extensions
AS $$
DECLARE
    v_student_id UUID := auth.uid();
    v_role TEXT;
    v_inst TEXT;
    v_std TEXT;
    v_div TEXT;
    v_med TEXT;
    v_group TEXT;
BEGIN
    SELECT role INTO v_role FROM public.users WHERE id = v_student_id;
    IF v_role != 'student' THEN
        RETURN;
    END IF;

    -- Extract student enrollment details
    SELECT 
        COALESCE(se.institution, u.institution, 'Sharda Mandir'),
        COALESCE(se.standard, u.class::text, '11'),
        COALESCE(se.division, u.division, 'A'),
        COALESCE(se.medium, u.medium, 'English'),
        COALESCE(se.student_group, u.student_group, '')
    INTO v_inst, v_std, v_div, v_med, v_group
    FROM public.users u
    LEFT JOIN public.student_enrollments se ON se.student_id = u.id
    WHERE u.id = v_student_id
    LIMIT 1;

    RETURN QUERY
    SELECT 
        u.id AS teacher_id,
        COALESCE(u.name, split_part(u.email, '@', 1)) AS name,
        u.email,
        array_agg(DISTINCT ta.subject) AS subjects
    FROM public.teacher_assignments ta
    JOIN public.users u ON u.id = ta.teacher_id
    WHERE u.is_active = true
      AND u.role = 'teacher'
      AND (
          (LOWER(ta.institution) LIKE '%acc%' AND LOWER(v_inst) LIKE '%acc%')
          OR LOWER(ta.institution) = LOWER(v_inst)
      )
      AND ta.standard = v_std
      AND (
          ta.division = 'ALL' 
          OR UPPER(ta.division) = UPPER(v_div)
          OR (LOWER(ta.institution) LIKE '%acc%' AND LOWER(v_inst) LIKE '%acc%')
      )
      AND (
          ta.medium IN ('Both', 'All') 
          OR LOWER(ta.medium) = LOWER(v_med)
      )
      AND (
          -- Compulsory subjects (Physics, Chemistry)
          LOWER(ta.subject) IN ('physics', 'physical', 'chemistry')
          OR (
              LOWER(ta.subject) IN ('biology', 'bio')
              AND (
                  v_group IS NULL 
                  OR LOWER(v_group) IN ('', 'biology', 'bio', 'b', 'science')
                  OR LOWER(v_group) LIKE '%bio%'
              )
          )
          OR (
              LOWER(ta.subject) IN ('math', 'maths', 'mathematics')
              AND (
                  LOWER(v_group) IN ('math', 'maths', 'a')
                  OR LOWER(v_group) LIKE '%math%'
              )
          )
          OR (
              LOWER(ta.subject) NOT IN ('physics', 'physical', 'chemistry', 'biology', 'bio', 'math', 'maths', 'mathematics')
          )
      )
    GROUP BY u.id, u.name, u.email
    ORDER BY u.name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_assigned_teachers() TO authenticated;

-- 12. RPC FUNCTION: get_or_create_conversation
-- Safely fetches or creates a conversation between an authorized teacher and student
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(p_teacher_id UUID, p_student_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_conv_id UUID;
BEGIN
    SELECT role INTO v_role FROM public.users WHERE id = v_user_id;
    
    -- Absolute privacy enforcement: Admin cannot create or join chat
    IF v_role = 'admin' THEN
        RAISE EXCEPTION 'Admins are strictly excluded from private chat functionality.';
    END IF;

    -- Caller must be one of the two participants
    IF v_user_id != p_teacher_id AND v_user_id != p_student_id THEN
        RAISE EXCEPTION 'You are not authorized to create or access this conversation.';
    END IF;

    -- Validate teacher assignment to student
    IF NOT public.is_teacher_assigned_to_student(p_teacher_id, p_student_id) THEN
        RAISE EXCEPTION 'Teacher is not assigned to this student.';
    END IF;

    -- Look up existing conversation
    SELECT id INTO v_conv_id
    FROM public.chat_conversations
    WHERE student_id = p_student_id AND teacher_id = p_teacher_id;

    -- Create if not present
    IF v_conv_id IS NULL THEN
        INSERT INTO public.chat_conversations (student_id, teacher_id)
        VALUES (p_student_id, p_teacher_id)
        ON CONFLICT (student_id, teacher_id) DO UPDATE SET student_id = EXCLUDED.student_id
        RETURNING id INTO v_conv_id;
    END IF;

    RETURN v_conv_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(UUID, UUID) TO authenticated;

-- 13. RPC FUNCTION: mark_messages_as_read
-- Safely marks all unread incoming messages in a conversation as read
CREATE OR REPLACE FUNCTION public.mark_messages_as_read(p_conversation_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
BEGIN
    SELECT role INTO v_role FROM public.users WHERE id = v_user_id;
    IF v_role = 'admin' THEN
        RAISE EXCEPTION 'Admins are strictly excluded from private chat functionality.';
    END IF;

    -- Verify user is a participant of this conversation
    IF NOT EXISTS (
        SELECT 1 FROM public.chat_conversations
        WHERE id = p_conversation_id
          AND (student_id = v_user_id OR teacher_id = v_user_id)
    ) THEN
        RAISE EXCEPTION 'Access denied to this conversation.';
    END IF;

    -- Update read_at for messages sent by the OTHER participant
    UPDATE public.chat_messages
    SET read_at = now()
    WHERE conversation_id = p_conversation_id
      AND sender_id != v_user_id
      AND read_at IS NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_messages_as_read(UUID) TO authenticated;

-- 14. RPC FUNCTION: get_user_conversations
-- Returns conversations for the current student or teacher with unread counts & partner profile
CREATE OR REPLACE FUNCTION public.get_user_conversations()
RETURNS TABLE (
    conversation_id UUID,
    student_id UUID,
    teacher_id UUID,
    other_user_id UUID,
    other_user_name TEXT,
    other_user_email TEXT,
    other_user_role TEXT,
    student_class TEXT,
    student_division TEXT,
    student_institution TEXT,
    last_message_at TIMESTAMPTZ,
    last_message_text TEXT,
    last_message_sender_id UUID,
    unread_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, extensions
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
BEGIN
    SELECT role INTO v_role FROM public.users WHERE id = v_user_id;
    
    -- Strict privacy boundary: Admin gets ZERO records
    IF v_role = 'admin' THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        c.id AS conversation_id,
        c.student_id,
        c.teacher_id,
        CASE WHEN c.student_id = v_user_id THEN c.teacher_id ELSE c.student_id END AS other_user_id,
        COALESCE(other_u.name, split_part(other_u.email, '@', 1)) AS other_user_name,
        other_u.email AS other_user_email,
        other_u.role AS other_user_role,
        COALESCE(se.standard, student_u.class::text, '11') AS student_class,
        COALESCE(se.division, student_u.division, 'A') AS student_division,
        COALESCE(se.institution, student_u.institution, 'Sharda Mandir') AS student_institution,
        c.last_message_at,
        c.last_message_text,
        c.last_message_sender_id,
        COUNT(m.id) FILTER (WHERE m.sender_id != v_user_id AND m.read_at IS NULL) AS unread_count
    FROM public.chat_conversations c
    JOIN public.users other_u ON other_u.id = (CASE WHEN c.student_id = v_user_id THEN c.teacher_id ELSE c.student_id END)
    JOIN public.users student_u ON student_u.id = c.student_id
    LEFT JOIN public.student_enrollments se ON se.student_id = c.student_id
    LEFT JOIN public.chat_messages m ON m.conversation_id = c.id
    WHERE c.student_id = v_user_id OR c.teacher_id = v_user_id
    GROUP BY 
        c.id, c.student_id, c.teacher_id, other_u.id, other_u.name, other_u.email, other_u.role,
        se.standard, student_u.class, se.division, student_u.division, se.institution, student_u.institution
    ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_conversations() TO authenticated;

-- 15. ENABLE SUPABASE REALTIME
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_conversations;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Realtime publication update handled for chat_conversations: %', SQLERRM;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Realtime publication update handled for chat_messages: %', SQLERRM;
END $$;

ALTER TABLE public.chat_conversations REPLICA IDENTITY FULL;
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

-- Status report
SELECT 'Private Teacher-Student Chat schema migration completed successfully.' AS status;
