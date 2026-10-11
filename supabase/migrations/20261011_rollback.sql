-- ============================================================================
-- MCQ Pro: Rollback Migration Script
-- Version: 20261011_rollback.sql
-- Description: Reverts changes made in 20261011_three_role_architecture.sql
--
-- ABSOLUTE RESTRICTION COMPLIANCE:
-- This script DOES NOT touch, alter, migrate, truncate, or drop public.keep_alive.
-- ============================================================================

-- Drop policies
DROP POLICY IF EXISTS "Cleanup runs access policy" ON public.cleanup_job_runs;
DROP POLICY IF EXISTS "Audit logs access policy" ON public.audit_logs;
DROP POLICY IF EXISTS "Performance aggregates access policy" ON public.student_performance_aggregates;
DROP POLICY IF EXISTS "Attempt backups access policy" ON public.attempt_backups;
DROP POLICY IF EXISTS "Backups access policy" ON public.test_backups;
DROP POLICY IF EXISTS "Insert answers policy" ON public.answers;
DROP POLICY IF EXISTS "Select answers policy" ON public.answers;
DROP POLICY IF EXISTS "Students insert own attempts" ON public.attempts;
DROP POLICY IF EXISTS "Select attempts policy" ON public.attempts;
DROP POLICY IF EXISTS "Teachers and admins manage questions" ON public.questions;
DROP POLICY IF EXISTS "Read questions policy" ON public.questions;
DROP POLICY IF EXISTS "Teachers and admins manage tests" ON public.tests;
DROP POLICY IF EXISTS "Select tests policy" ON public.tests;
DROP POLICY IF EXISTS "Manage student enrollments" ON public.student_enrollments;
DROP POLICY IF EXISTS "Read student enrollments" ON public.student_enrollments;
DROP POLICY IF EXISTS "Admin manage teacher assignments" ON public.teacher_assignments;
DROP POLICY IF EXISTS "Read teacher assignments" ON public.teacher_assignments;
DROP POLICY IF EXISTS "Admins manage academic configurations" ON public.academic_configurations;
DROP POLICY IF EXISTS "Read academic configurations" ON public.academic_configurations;
DROP POLICY IF EXISTS "Admins can insert or manage users" ON public.users;
DROP POLICY IF EXISTS "Users can read own profile or admins can read all" ON public.users;

-- Drop newly created tables
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.cleanup_job_runs CASCADE;
DROP TABLE IF EXISTS public.student_performance_aggregates CASCADE;
DROP TABLE IF EXISTS public.attempt_backups CASCADE;
DROP TABLE IF EXISTS public.test_backups CASCADE;
DROP TABLE IF EXISTS public.student_enrollments CASCADE;
DROP TABLE IF EXISTS public.teacher_assignments CASCADE;
DROP TABLE IF EXISTS public.academic_configurations CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS public.allocate_student_roll_no(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.is_teacher();
DROP FUNCTION IF EXISTS public.is_admin();
DROP FUNCTION IF EXISTS public.current_user_role();

-- Revert users table role constraint (if no 'admin' user remains)
DO $$
BEGIN
    ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
    ALTER TABLE public.users ADD CONSTRAINT users_role_check 
        CHECK (role IN ('teacher', 'student'));
EXCEPTION
    WHEN OTHERS THEN 
        RAISE NOTICE 'Rollback constraint handled: %', SQLERRM;
END $$;
