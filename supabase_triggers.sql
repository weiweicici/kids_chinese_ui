-- 注册后自动创建 profile + registration_requests
-- 不再依赖 app 端 REST API 调用
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  _username text;
BEGIN
  _username := COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1));
  INSERT INTO public.profiles (id, username, display_name, role, is_approved)
  VALUES (NEW.id, _username, _username, 'student', false);
  INSERT INTO public.registration_requests (user_id, status)
  VALUES (NEW.id, 'pending');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
