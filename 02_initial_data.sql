-- Optional starter data for Arcadium.
-- Execute after 01_create_tables.sql. Edit names/rewards to match the project wiki.

BEGIN;

INSERT INTO achievements (name, description, reward_amount, achievement_type) VALUES
    ('Первое мероприятие', 'Посещение первого мероприятия Аркадиума', 50, 'automatic'),
    ('Победитель турнира', 'Победа в турнире по мастер-классу', 100, 'admin'),
    ('Лучший косплей', 'Награда за лучший косплей', 100, 'admin'),
    ('Исследователь', 'Достижение в одной из мини-игр', 50, 'automatic')
ON CONFLICT (name) DO NOTHING;

INSERT INTO award_topics (name, description) VALUES
    ('Мероприятия', 'Начисления за участие в мероприятиях'),
    ('Активность', 'Начисления за активность в проекте')
ON CONFLICT (name) DO NOTHING;

-- Example actions. Amounts are placeholders and should be confirmed by the project team.
INSERT INTO award_actions (topic_id, name, description, reward_amount)
SELECT t.id, v.action_name, v.action_description, v.reward_amount
FROM award_topics t
JOIN (VALUES
    ('Мероприятия', 'Посещение мероприятия', 'Награда за посещение мероприятия', 20::BIGINT),
    ('Мероприятия', 'Живой пиар', 'Награда за участие в живом пиаре', 30::BIGINT),
    ('Активность', 'Помощь организаторам', 'Награда за помощь команде', 15::BIGINT)
) AS v(topic_name, action_name, action_description, reward_amount)
  ON t.name = v.topic_name
ON CONFLICT (topic_id, name) DO NOTHING;

COMMIT;
