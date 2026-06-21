-- profiles 表（关联 auth.users）
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL,
  display_name text,
  role text DEFAULT 'student' CHECK (role IN ('student', 'admin')),
  is_approved boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- user_progress 表
CREATE TABLE user_progress (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  feature text NOT NULL CHECK (feature IN ('main', 'game1', 'game2', 'game3')),
  book_number int NOT NULL,
  lesson_number int NOT NULL,
  word_index int,
  updated_at timestamptz DEFAULT now(),
  UNIQUE (user_id, feature)
);

ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;

-- registration_requests 表（审批队列）
CREATE TABLE registration_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  approved_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE registration_requests ENABLE ROW LEVEL SECURITY;
