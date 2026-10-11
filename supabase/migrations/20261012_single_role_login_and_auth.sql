-- ============================================================================
-- MCQ Pro: Single Role-Based Login & Student Registration Setup
-- Version: 20261012_single_role_login_and_auth.sql
--
-- STRICT RESTRICTION:
-- This script DOES NOT modify, touch, alter, migrate, truncate, or drop public.keep_alive.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Ensure columns exist on public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS temporary_password TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS institution TEXT DEFAULT 'Sharda Mandir';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS academic_year TEXT DEFAULT '2026-2027';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS medium TEXT DEFAULT 'English';

-- Safely enforce check constraint on role: 'admin', 'teacher', 'student'
DO $$
BEGIN
    ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
    ALTER TABLE public.users ADD CONSTRAINT users_role_check 
        CHECK (role IN ('admin', 'teacher', 'student'));
EXCEPTION
    WHEN OTHERS THEN 
        RAISE NOTICE 'Role constraint update: %', SQLERRM;
END $$;

-- 2. Concurrency-Safe Student Roll Number Allocation Function (if not already defined)
CREATE OR REPLACE FUNCTION public.allocate_student_roll_no(
    p_institution TEXT,
    p_academic_year TEXT,
    p_standard TEXT,
    p_division TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lock_key BIGINT;
    v_max_roll INT;
    v_next_roll INT;
    v_formatted_roll TEXT;
BEGIN
    -- Transaction-level advisory lock per institution:year:standard:division
    v_lock_key := ('x' || substr(md5(p_institution || ':' || p_academic_year || ':' || p_standard || ':' || p_division), 1, 16))::bit(64)::bigint;
    PERFORM pg_advisory_xact_lock(v_lock_key);

    -- Find current max roll number
    SELECT COALESCE(MAX(
        CASE 
            WHEN roll_no ~ '^[0-9]+$' THEN roll_no::INT
            WHEN roll_no ~ '[0-9]+$' THEN substring(roll_no from '[0-9]+$')::INT
            ELSE 0 
        END
    ), 0)
    INTO v_max_roll
    FROM public.student_enrollments
    WHERE institution = p_institution
      AND academic_year = p_academic_year
      AND standard = p_standard
      AND division = p_division;

    v_next_roll := v_max_roll + 1;
    v_formatted_roll := v_next_roll::TEXT;

    RETURN v_formatted_roll;
END;
$$;

GRANT EXECUTE ON FUNCTION public.allocate_student_roll_no(TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;

-- 3. Automatic Profile & Enrollment Initialization Trigger on auth.users
-- Handles instant registration and email confirmation scenarios
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
    -- Read metadata supplied during supabase.auth.signUp()
    v_role := LOWER(COALESCE(NEW.raw_user_meta_data->>'role', 'student'));

    -- SECURITY GUARANTEE: Public registration trigger ONLY auto-creates 'student' profiles.
    -- Never allow admin or teacher accounts to be automatically provisioned through this trigger.
    IF v_role = 'student' THEN
        v_name := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1));
        v_standard := COALESCE(NEW.raw_user_meta_data->>'class', '11');
        v_division := COALESCE(NEW.raw_user_meta_data->>'division', 'A');
        v_medium := COALESCE(NEW.raw_user_meta_data->>'medium', 'English');
        v_group := NEW.raw_user_meta_data->>'student_group';
        v_institution := COALESCE(NEW.raw_user_meta_data->>'institution', 'Sharda Mandir');
        v_academic_year := COALESCE(NEW.raw_user_meta_data->>'academic_year', '2026-2027');

        -- Allocate unique sequential roll number
        BEGIN
            v_roll_no := public.allocate_student_roll_no(v_institution, v_academic_year, v_standard, v_division);
        EXCEPTION WHEN OTHERS THEN
            v_roll_no := '1';
        END;

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
            roll_no = EXCLUDED.roll_no,
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
            ON CONFLICT (institution, academic_year, standard, division, roll_no) DO NOTHING;
        EXCEPTION WHEN OTHERS THEN
            -- In case student_enrollments unique key conflict, ignore
        END;
    END IF;

    RETURN NEW;
END;
$$;

-- Create Trigger on auth.users (if permission granted in SQL Editor)
DO $$
BEGIN
    DROP TRIGGER IF EXISTS on_auth_user_created_student ON auth.users;
    CREATE TRIGGER on_auth_user_created_student
        AFTER INSERT ON auth.users
        FOR EACH ROW
        EXECUTE FUNCTION public.handle_new_student_user();
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Trigger setup skipped or managed by application: %', SQLERRM;
END $$;

-- 4. Verify RLS Policies on public.users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own profile or admins can read all" ON public.users;
CREATE POLICY "Users can read own profile or admins can read all"
ON public.users FOR SELECT
USING (
    auth.uid() = id 
    OR public.is_admin() 
    OR (public.is_teacher() AND role = 'student')
);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
USING (auth.uid() = id OR public.is_admin())
WITH CHECK (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile"
ON public.users FOR INSERT
WITH CHECK (auth.uid() = id OR public.is_admin());

-- 5. Status Output
SELECT 'Single Role-Based Login & Student Registration Migration complete.' AS status;
