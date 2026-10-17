-- ============================================================================
-- Migration: Fix and Guarantee Unique Sequential Student Roll Numbers
-- Description:
--   1. Redefines allocate_student_roll_no to find the global MAX roll number
--      across ALL students (rather than resetting to 1 per division/standard)
--      and returns MAX + 1.
--   2. Updates handle_new_student_user auth trigger to use global roll allocation.
--   3. Renumbers all existing students sequentially (1, 2, 3...) based on created_at
--      to eliminate duplicate roll numbers (e.g. where all students had Roll #1).
-- ============================================================================

-- 1. Global Concurrency-Safe Student Roll Number Allocation Function
CREATE OR REPLACE FUNCTION public.allocate_student_roll_no(
    p_institution TEXT DEFAULT NULL,
    p_academic_year TEXT DEFAULT NULL,
    p_standard TEXT DEFAULT NULL,
    p_division TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_lock_key BIGINT;
    v_max_roll INT;
    v_next_roll INT;
    v_formatted_roll TEXT;
BEGIN
    -- Transaction-level advisory lock across student roll allocation to prevent race conditions
    v_lock_key := ('x' || substr(md5('student_global_roll_allocation_lock'), 1, 16))::bit(64)::bigint;
    PERFORM pg_advisory_xact_lock(v_lock_key);

    -- Find the current highest numeric roll number across ALL students in public.users and public.student_enrollments
    SELECT COALESCE(MAX(roll_val), 0)
    INTO v_max_roll
    FROM (
        SELECT 
            CASE 
                WHEN roll_no ~ '^[0-9]+$' THEN roll_no::INT
                WHEN roll_no ~ '[0-9]+$' THEN substring(roll_no from '[0-9]+$')::INT
                ELSE 0 
            END AS roll_val
        FROM public.users
        WHERE role = 'student'
        UNION ALL
        SELECT 
            CASE 
                WHEN roll_no ~ '^[0-9]+$' THEN roll_no::INT
                WHEN roll_no ~ '[0-9]+$' THEN substring(roll_no from '[0-9]+$')::INT
                ELSE 0 
            END AS roll_val
        FROM public.student_enrollments
    ) s;

    v_next_roll := v_max_roll + 1;
    v_formatted_roll := v_next_roll::TEXT;

    RETURN v_formatted_roll;
END;
$$;

-- Allow calling without arguments as well
CREATE OR REPLACE FUNCTION public.allocate_student_roll_no()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    RETURN public.allocate_student_roll_no(NULL, NULL, NULL, NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION public.allocate_student_roll_no(TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.allocate_student_roll_no() TO authenticated, anon;

-- 2. Update auth.users registration trigger
CREATE OR REPLACE FUNCTION public.handle_new_student_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_role TEXT;
    v_name TEXT;
    v_standard TEXT;
    v_division TEXT;
    v_medium TEXT;
    v_group TEXT;
    v_institution TEXT;
    v_academic_year TEXT;
    v_roll_no TEXT;
BEGIN
    v_role := LOWER(COALESCE(NEW.raw_user_meta_data->>'role', 'student'));

    IF v_role = 'student' THEN
        v_name := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));
        v_standard := COALESCE(NEW.raw_user_meta_data->>'class', '11');
        v_division := COALESCE(NEW.raw_user_meta_data->>'division', 'A');
        v_medium := COALESCE(NEW.raw_user_meta_data->>'medium', 'English');
        v_group := NEW.raw_user_meta_data->>'student_group';
        v_institution := COALESCE(NEW.raw_user_meta_data->>'institution', 'Sharda Mandir');
        v_academic_year := COALESCE(NEW.raw_user_meta_data->>'academic_year', '2026-2027');

        -- Allocate globally unique sequential roll number
        BEGIN
            v_roll_no := public.allocate_student_roll_no(v_institution, v_academic_year, v_standard, v_division);
        EXCEPTION WHEN OTHERS THEN
            v_roll_no := NULL;
        END;

        IF v_roll_no IS NULL OR v_roll_no = '' THEN
            SELECT (COALESCE(MAX(
                CASE 
                    WHEN roll_no ~ '^[0-9]+$' THEN roll_no::INT
                    WHEN roll_no ~ '[0-9]+$' THEN substring(roll_no from '[0-9]+$')::INT
                    ELSE 0 
                END
            ), 0) + 1)::TEXT
            INTO v_roll_no
            FROM public.users
            WHERE role = 'student';
        END IF;

        -- 1. Insert into public.users
        INSERT INTO public.users (
            id,
            email,
            name,
            role,
            class,
            division,
            medium,
            student_group,
            roll_no,
            institution,
            academic_year,
            is_active,
            must_change_password
        ) VALUES (
            NEW.id,
            LOWER(NEW.email),
            v_name,
            'student',
            v_standard::INT,
            v_division,
            v_medium,
            v_group,
            v_roll_no,
            v_institution,
            v_academic_year,
            true,
            false
        )
        ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            name = EXCLUDED.name,
            role = 'student',
            class = EXCLUDED.class,
            division = EXCLUDED.division,
            medium = EXCLUDED.medium,
            student_group = EXCLUDED.student_group,
            roll_no = COALESCE(public.users.roll_no, EXCLUDED.roll_no),
            is_active = true;

        -- 2. Insert into public.student_enrollments
        BEGIN
            INSERT INTO public.student_enrollments (
                student_id,
                institution,
                academic_year,
                standard,
                division,
                medium,
                student_group,
                roll_no
            ) VALUES (
                NEW.id,
                v_institution,
                v_academic_year,
                v_standard,
                v_division,
                v_medium,
                v_group,
                v_roll_no
            )
            ON CONFLICT (institution, academic_year, standard, division, roll_no) DO UPDATE SET
                student_id = EXCLUDED.student_id;
        EXCEPTION WHEN OTHERS THEN
            -- In case of duplicate or conflict
        END;
    END IF;

    RETURN NEW;
END;
$$;

-- 3. Renumber all existing students with duplicate roll numbers
-- Chronologically ordered by created_at: Keyur -> 1, Anand -> 2, Student -> 3, etc.
DO $$
DECLARE
    rec RECORD;
    v_seq INT := 1;
BEGIN
    FOR rec IN 
        SELECT id 
        FROM public.users 
        WHERE role = 'student' 
        ORDER BY created_at ASC, email ASC
    LOOP
        UPDATE public.users 
        SET roll_no = v_seq::TEXT 
        WHERE id = rec.id;

        UPDATE public.student_enrollments 
        SET roll_no = v_seq::TEXT 
        WHERE student_id = rec.id;

        v_seq := v_seq + 1;
    END LOOP;
END $$;
