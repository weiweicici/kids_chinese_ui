-- 管理员检测函数
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- === profiles 表策略 ===
-- 用户可创建自己的资料（注册时）
CREATE POLICY "users_insert_own_profile" ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

-- 用户可看自己的资料；管理员可看所有
CREATE POLICY "users_select_own_or_admin" ON profiles FOR SELECT
  USING (id = auth.uid() OR is_admin());

-- 仅管理员可更新（审批 role/is_approved）
CREATE POLICY "admin_update_profiles" ON profiles FOR UPDATE
  USING (is_admin());

-- === user_progress 表策略 ===
-- 用户可完全管理自己的进度记录
CREATE POLICY "users_manage_own_progress" ON user_progress FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- === registration_requests 表策略 ===
-- 用户可提交自己的注册申请
CREATE POLICY "users_insert_own_request" ON registration_requests FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- 仅管理员可查看和管理申请
CREATE POLICY "admin_manage_requests" ON registration_requests FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());
