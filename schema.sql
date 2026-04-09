CREATE TABLE users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text NOT NULL,
    display_name text,
    avatar_url text,
    total_points integer DEFAULT 0,
    games_played integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE games (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code text UNIQUE NOT NULL,
    letter char NOT NULL,
    round_duration_seconds integer DEFAULT 60,
    max_players integer DEFAULT 6,
    status text DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'completed', 'cancelled')),
    host_id uuid REFERENCES users(id) ON DELETE SET NULL,
    start_time timestamptz,
    end_time timestamptz,
    categories jsonb DEFAULT '["country", "city", "animal", "food", "name", "object"]'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE game_players (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id uuid REFERENCES games(id) ON DELETE CASCADE,
    user_id uuid REFERENCES users(id) ON DELETE CASCADE,
    is_ready boolean DEFAULT false,
    joined_at timestamptz DEFAULT now(),
    UNIQUE(game_id, user_id)
);

CREATE TABLE submissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id uuid REFERENCES games(id) ON DELETE CASCADE,
    user_id uuid REFERENCES users(id) ON DELETE CASCADE,
    round_number integer DEFAULT 1,
    category text NOT NULL,
    word_hebrew text NOT NULL,
    word_transliterated text,
    is_valid boolean,
    points_awarded integer DEFAULT 0,
    submitted_at timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE scores (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id uuid REFERENCES games(id) ON DELETE CASCADE,
    user_id uuid REFERENCES users(id) ON DELETE CASCADE,
    total_points integer DEFAULT 0,
    words_submitted jsonb DEFAULT '[]'::jsonb,
    rank integer,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(game_id, user_id)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_games_room_code ON games(room_code);
CREATE INDEX idx_games_status ON games(status);
CREATE INDEX idx_games_host_id ON games(host_id);
CREATE INDEX idx_game_players_game_id ON game_players(game_id);
CREATE INDEX idx_game_players_user_id ON game_players(user_id);
CREATE INDEX idx_submissions_game_id ON submissions(game_id);
CREATE INDEX idx_submissions_user_id ON submissions(user_id);
CREATE INDEX idx_submissions_game_user_round ON submissions(game_id, user_id, round_number);
CREATE INDEX idx_scores_game_id ON scores(game_id);
CREATE INDEX idx_scores_user_id ON scores(user_id);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all users" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can view all games" ON games FOR SELECT USING (true);
CREATE POLICY "Hosts can manage their games" ON games FOR ALL USING (auth.uid() = host_id);
CREATE POLICY "Players can view game players" ON game_players FOR SELECT USING (true);
CREATE POLICY "Players can join games" ON game_players FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Players can update their ready status" ON game_players FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Players can view all submissions" ON submissions FOR SELECT USING (true);
CREATE POLICY "Players can submit their own words" ON submissions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Players can view all scores" ON scores FOR SELECT USING (true);
CREATE POLICY "System can manage scores" ON scores FOR ALL USING (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_games_updated_at BEFORE UPDATE ON games FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_submissions_updated_at BEFORE UPDATE ON submissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON scores FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();