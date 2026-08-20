-- bot иµ„ж–™(name/about/description/commands/menu_button)еЏж›ґйѓЅдјљ bump users.bot_info_version
-- (BumpBotInfoVersion,и§Ѓ bot.sql)гЂ‚зѕ¤дїЎжЃЇйЎµзљ„ ChannelFull.bot_info з”± RPC е±‚
-- channelFullBotInfoCache зј“е­(й”®=viewer+channel,ж— жі•жЊ‰ bot е®љдЅЌ),е…¶и·Ёе®ћдѕ‹е¤±ж•€ж­¤е‰ЌеЏЄжЊ‚ењЁ
-- channel_base/channel_member дє‹д»¶дёЉвЂ”вЂ”bot и‡Єиє«ж”№иµ„ж–™(з»Џ BotFather жњ¬ењ°и·Їеѕ„,ж€–е…¶е®ѓе®ћдѕ‹зљ„
-- bots.* RPC)дёЌдјље¤±ж•€иЇҐзј“е­,еЇји‡ґзѕ¤дїЎжЃЇйЎµй‡ЊиЇҐ bot зљ„з®Ђд»‹/е‘Ѕд»¤й™€ж—§жњЂй•ї 30 е€†й’џ(TTL)гЂ‚
--
-- иї™й‡Њз»™ bot иµ„ж–™еЏж›ґеЌ•з‹¬еЏ‘дёЂдёЄ 'bot_full' read-model дє‹д»¶;ReadModelChangeListener ж”¶е€°еЌі
-- flush channelFullBotInfoCache(жњ¬ењ° BotFather и·Їеѕ„дёЋи·Ёе®ћдѕ‹ bots.* RPC дё¤жќЎж›ґж–°и·Їеѕ„йѓЅи¦†з›–)гЂ‚
-- дёЋж—ўжњ‰ user_base дє‹д»¶(и¦†з›– RPC жЉ•еЅ±/Redis user:base/bot иµ„ж–™зј“е­)дє’иЎҐ,дёЌж”№еЉЁ user_base зѓ­и·Їеѕ„гЂ‚

CREATE FUNCTION public.telesrv_notify_bot_full_read_model() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.is_bot AND (OLD.bot_info_version IS DISTINCT FROM NEW.bot_info_version) THEN
        PERFORM telesrv_bump_read_model_version('bot_full', NEW.id, 'user', NEW.id);
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER users_bot_full_read_model_changed
    AFTER UPDATE ON public.users
    FOR EACH ROW
    EXECUTE PROCEDURE public.telesrv_notify_bot_full_read_model();
