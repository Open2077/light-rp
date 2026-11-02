-- Persistence of the Neural-Link: one MariaDB schema, read and written through
-- the platform's MySQL bridge. Ids that are not GUIDs are never CHAR(36): the
-- server's driver reads CHAR(36) back as a GUID and fails on anything else.
--
-- Every helper distinguishes "no row" from "the database failed": a failed
-- read must never look like an empty inbox or a free phone number.
Neural = Neural or {}
local Store = { ready = false }
Neural.store = Store

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS nl_lines (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        number VARCHAR(16) NOT NULL,
        identifier VARCHAR(128) NOT NULL,
        character_key VARCHAR(64) NOT NULL,
        name VARCHAR(64) NULL,
        settings TEXT NULL,
        created_at BIGINT NOT NULL,
        UNIQUE KEY nl_line_number (number),
        UNIQUE KEY nl_line_owner (identifier, character_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_contacts (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        line_id BIGINT NOT NULL,
        name VARCHAR(48) NOT NULL,
        number VARCHAR(16) NOT NULL,
        favorite TINYINT NOT NULL DEFAULT 0,
        UNIQUE KEY nl_contact_number (line_id, number)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_threads (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        kind VARCHAR(8) NOT NULL,
        title VARCHAR(48) NULL,
        direct_key VARCHAR(48) NULL,
        created_at BIGINT NOT NULL,
        updated_at BIGINT NOT NULL,
        UNIQUE KEY nl_thread_direct (direct_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_members (
        thread_id BIGINT NOT NULL,
        line_id BIGINT NOT NULL,
        role VARCHAR(8) NOT NULL DEFAULT 'member',
        active TINYINT NOT NULL DEFAULT 1,
        last_read BIGINT NOT NULL DEFAULT 0,
        joined_at BIGINT NOT NULL,
        PRIMARY KEY (thread_id, line_id),
        KEY nl_member_line (line_id, active)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_messages (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        thread_id BIGINT NOT NULL,
        sender_line BIGINT NULL,
        kind VARCHAR(8) NOT NULL DEFAULT 'text',
        body TEXT NOT NULL,
        at BIGINT NOT NULL,
        KEY nl_message_thread (thread_id, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_calls (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        line_id BIGINT NOT NULL,
        peer_number VARCHAR(16) NOT NULL,
        label VARCHAR(48) NULL,
        direction VARCHAR(3) NOT NULL,
        status VARCHAR(12) NOT NULL,
        at BIGINT NOT NULL,
        duration INT NOT NULL DEFAULT 0,
        KEY nl_call_line (line_id, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    -- The implant (lines.lua): a line without one sees only the installation screen.
    [[ALTER TABLE nl_lines ADD COLUMN IF NOT EXISTS installed_at BIGINT NULL]],
    -- Rich messages from other resources (server/messages.lua Messages.deliver): a JSON
    -- object with a card, action buttons, a location and the resolved state.
    [[ALTER TABLE nl_messages ADD COLUMN IF NOT EXISTS meta MEDIUMTEXT NULL]],
    -- Screamsheet (server/social.lua): one profile per line.
    [[CREATE TABLE IF NOT EXISTS nl_social_profiles (
        line_id BIGINT NOT NULL PRIMARY KEY,
        handle VARCHAR(16) NOT NULL,
        name VARCHAR(32) NOT NULL,
        bio VARCHAR(160) NOT NULL DEFAULT '',
        created_at BIGINT NOT NULL,
        UNIQUE KEY nl_social_handle (handle)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    -- A plain echo is a row with echo_of set and an empty body; a quote has both.
    [[CREATE TABLE IF NOT EXISTS nl_social_posts (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        line_id BIGINT NOT NULL,
        body VARCHAR(1200) NOT NULL DEFAULT '',
        reply_to BIGINT NULL,
        echo_of BIGINT NULL,
        district VARCHAR(40) NULL,
        created_at BIGINT NOT NULL,
        deleted TINYINT NOT NULL DEFAULT 0,
        replies INT NOT NULL DEFAULT 0,
        echoes INT NOT NULL DEFAULT 0,
        cred INT NOT NULL DEFAULT 0,
        KEY nl_social_post_time (created_at),
        KEY nl_social_post_line (line_id, id),
        KEY nl_social_post_reply (reply_to, id),
        KEY nl_social_post_echo (echo_of, line_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_social_cred (
        post_id BIGINT NOT NULL,
        line_id BIGINT NOT NULL,
        created_at BIGINT NOT NULL,
        PRIMARY KEY (post_id, line_id),
        KEY nl_social_cred_line (line_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_social_follows (
        follower BIGINT NOT NULL,
        followee BIGINT NOT NULL,
        created_at BIGINT NOT NULL,
        PRIMARY KEY (follower, followee),
        KEY nl_social_followee (followee)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_social_tags (
        post_id BIGINT NOT NULL,
        tag VARCHAR(32) NOT NULL,
        created_at BIGINT NOT NULL,
        PRIMARY KEY (post_id, tag),
        KEY nl_social_tag_time (tag, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_social_pings (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        line_id BIGINT NOT NULL,
        kind VARCHAR(8) NOT NULL,
        actor_line BIGINT NOT NULL,
        post_id BIGINT NULL,
        created_at BIGINT NOT NULL,
        is_read TINYINT NOT NULL DEFAULT 0,
        KEY nl_social_ping_line (line_id, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS nl_social_reports (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        post_id BIGINT NOT NULL,
        line_id BIGINT NOT NULL,
        reason VARCHAR(140) NOT NULL,
        created_at BIGINT NOT NULL,
        UNIQUE KEY nl_social_report_once (post_id, line_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local readyHandlers = {}

function Store.onReady(fn)
    if Store.ready then CreateThread(fn) else readyHandlers[#readyHandlers + 1] = fn end
end

local function log(fmt, ...) print("[neuralink] " .. string.format(fmt, ...)) end
Neural.log = log

function Neural.nowMs() return math.floor(Open77.time.unix() * 1000) end

-- query: rows (possibly empty) or nil, error
function Store.query(sql, params)
    if not Store.ready then return nil, "database_unavailable" end
    local ok, rows = pcall(MySQL.query.await, sql, params)
    if not ok or type(rows) ~= "table" then
        log("query failed: %s", tostring(rows))
        return nil, "database_unavailable"
    end
    return rows
end

-- single: row, or false when there is none; nil, error on failure
function Store.single(sql, params)
    local rows, err = Store.query(sql, params)
    if not rows then return nil, err end
    return rows[1] or false
end

function Store.insert(sql, params)
    if not Store.ready then return nil, "database_unavailable" end
    local ok, id = pcall(MySQL.insert.await, sql, params)
    if not ok then
        log("insert failed: %s", tostring(id))
        return nil, tostring(id):find("Duplicate", 1, true) and "conflict" or "database_unavailable"
    end
    return id
end

function Store.update(sql, params)
    if not Store.ready then return nil, "database_unavailable" end
    local ok, affected = pcall(MySQL.update.await, sql, params)
    if not ok then
        log("update failed: %s", tostring(affected))
        return nil, "database_unavailable"
    end
    return affected
end

function Store.transaction(statements)
    if not Store.ready then return nil, "database_unavailable" end
    local ok, committed = pcall(MySQL.transaction.await, statements)
    if not ok or committed ~= true then
        log("transaction failed: %s", tostring(committed))
        return nil, "database_unavailable"
    end
    return true
end

-- "?, ?, ?" for an IN list (the bridge accepts at most 64 parameters).
function Store.placeholders(n)
    local p = {}
    for i = 1, n do p[i] = "?" end
    return table.concat(p, ",")
end

local ready, why = MySQL.ready(function()
    for _, sql in ipairs(SCHEMA) do
        local ok, err = pcall(MySQL.update.await, sql)
        if not ok then
            log("schema failed: %s", tostring(err))
            return
        end
    end
    Store.ready = true
    log("persistence ready (%d tables)", #SCHEMA)
    for _, fn in ipairs(readyHandlers) do CreateThread(fn) end
    readyHandlers = {}
end)
if not ready then log("no database (%s): the Neural-Link cannot assign lines", tostring(why)) end
