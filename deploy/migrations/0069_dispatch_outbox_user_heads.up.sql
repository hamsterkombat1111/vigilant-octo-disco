-- Claim еЏЄйњЂи¦ЃжџҐзњ‹жЇЏдёЄз”Ёж€·еЅ“е‰ЌжњЄе®Њж€ђ headгЂ‚жЉЉ head жЊЃд№…еЊ–еђЋпјЊйў†еЏ–е¤Ќжќ‚еє¦з”±
-- вЂњж‰«жЏЏе…ЁйѓЁ outbox з§ЇеЋ‹е№¶ DISTINCT ONвЂќй™ЌдёєвЂњж‰«жЏЏжњ‰з§ЇеЋ‹зљ„з”Ёж€· laneвЂќгЂ‚
-- иїЃз§»жњџй—ґй»ж­ўе№¶еЏ‘е†™пјЊдїќиЇЃ backfill дёЋйљЏеђЋе®‰иЈ…зљ„и§¦еЏ‘е™Ёд№‹й—ґжІЎжњ‰зјєеЏЈгЂ‚
LOCK TABLE dispatch_outbox IN SHARE ROW EXCLUSIVE MODE;

CREATE TABLE dispatch_outbox_user_heads (
    target_user_id bigint PRIMARY KEY,
    head_id bigint NOT NULL,
    head_pts integer NOT NULL CHECK (head_pts >= 0),
    logical_shard smallint NOT NULL DEFAULT 0,
    CHECK (logical_shard >= 0 AND logical_shard < 256)
);

CREATE OR REPLACE FUNCTION dispatch_outbox_user_heads_set_shard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.logical_shard := mod(NEW.target_user_id, 256::bigint)::smallint;
    RETURN NEW;
END;
$$;

CREATE TRIGGER dispatch_outbox_user_heads_set_shard_trg
BEFORE INSERT OR UPDATE ON dispatch_outbox_user_heads
FOR EACH ROW
EXECUTE PROCEDURE dispatch_outbox_user_heads_set_shard();

CREATE INDEX dispatch_outbox_user_heads_shard_idx
    ON dispatch_outbox_user_heads (logical_shard, target_user_id);

INSERT INTO dispatch_outbox_user_heads (target_user_id, head_id, head_pts)
SELECT DISTINCT ON (target_user_id)
    target_user_id,
    id,
    pts
FROM dispatch_outbox
ORDER BY target_user_id ASC, pts ASC, id ASC;

CREATE FUNCTION dispatch_outbox_maintain_user_head()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    removed_head bigint;
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO dispatch_outbox_user_heads (target_user_id, head_id, head_pts)
        VALUES (NEW.target_user_id, NEW.id, NEW.pts)
        ON CONFLICT (target_user_id) DO UPDATE
        SET head_id = EXCLUDED.head_id,
            head_pts = EXCLUDED.head_pts
        WHERE (EXCLUDED.head_pts, EXCLUDED.head_id) <
              (dispatch_outbox_user_heads.head_pts, dispatch_outbox_user_heads.head_id);
        RETURN NULL;
    END IF;

    -- е€ й™¤йќћ head дёЌйњЂи¦Ѓй‡Ќз®—гЂ‚е€ й™¤ head ж—¶з”Ё (target_user_id, pts, id)
    -- зґўеј•ж‰ѕдё‹дёЂжќЎпј›failed head еђЊж ·дјљдёЂз›ґй»еЎћпјЊз›ґе€°иў«жѕејЏе€ й™¤гЂ‚
    DELETE FROM dispatch_outbox_user_heads
    WHERE target_user_id = OLD.target_user_id
      AND head_id = OLD.id
    RETURNING head_id INTO removed_head;

    IF removed_head IS NOT NULL THEN
        INSERT INTO dispatch_outbox_user_heads (target_user_id, head_id, head_pts)
        SELECT target_user_id, id, pts
        FROM dispatch_outbox
        WHERE target_user_id = OLD.target_user_id
        ORDER BY pts ASC, id ASC
        LIMIT 1
        ON CONFLICT (target_user_id) DO UPDATE
        SET head_id = EXCLUDED.head_id,
            head_pts = EXCLUDED.head_pts
        WHERE (EXCLUDED.head_pts, EXCLUDED.head_id) <
              (dispatch_outbox_user_heads.head_pts, dispatch_outbox_user_heads.head_id);
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER dispatch_outbox_insert_user_head
AFTER INSERT ON dispatch_outbox
FOR EACH ROW
EXECUTE PROCEDURE dispatch_outbox_maintain_user_head();

CREATE TRIGGER dispatch_outbox_delete_user_head
AFTER DELETE ON dispatch_outbox
FOR EACH ROW
EXECUTE PROCEDURE dispatch_outbox_maintain_user_head();

-- Claim е·ІдёЌе†ЌиЇ»еЏ–иЎЁиѕѕејЏ shard зґўеј•пј›з§»й™¤е®ѓйЃїе…ЌжЇЏж¬Ў enqueue зљ„й‡Ќе¤Ќе†™ж”ѕе¤§гЂ‚
DROP INDEX IF EXISTS dispatch_outbox_logical_shard_head_idx;
