CREATE TABLE "conversation_participants" (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  conversation_database_identifier INTEGER NOT NULL,
  stream_member_database_identifier INTEGER,
  member_id TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  deleted_at DATETIME,
  seq INTEGER,
  event_database_identifier INTEGER UNIQUE,
  UNIQUE(conversation_database_identifier, member_id),
  FOREIGN KEY(conversation_database_identifier) REFERENCES conversations(database_identifier) ON DELETE CASCADE,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE
);

CREATE TABLE "conversations" (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  stream_database_identifier INTEGER UNIQUE,
  stream_id BLOB UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at DATETIME,
  object_identifier TEXT UNIQUE NOT NULL,
  version INT NOT NULL
);

CREATE TABLE event_content_parts (
  event_content_part_id INTEGER NOT NULL,
  event_database_identifier INTEGER NOT NULL,
  type TEXT NOT NULL,
  value BLOB,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE,
  PRIMARY KEY(event_content_part_id, event_database_identifier)
);

CREATE TABLE event_metadata (
  event_database_identifier INTEGER NOT NULL,
  key TEXT NOT NULL,
  value BLOB NOT NULL,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE,
  PRIMARY KEY(event_database_identifier, key)
);

CREATE TABLE "events" (
  database_identifier INTEGER PRIMARY KEY AUTOINCREMENT,
  type INTEGER NOT NULL,
  creator_id TEXT,
  seq INTEGER,
  timestamp INTEGER,
  preceding_seq INTEGER,
  client_seq INTEGER NOT NULL,
  subtype INTEGER,
  external_content_id BLOB,
  member_id TEXT,
  target_seq INTEGER,
  stream_database_identifier INTEGER NOT NULL,
  version INTEGER, 
  client_id TEXT,
  UNIQUE(stream_database_identifier, seq),
  FOREIGN KEY(stream_database_identifier) REFERENCES streams(database_identifier) ON DELETE CASCADE
);

CREATE TABLE "keyed_values" (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  object_type TEXT NOT NULL,
  object_id INTEGER NOT NULL,
  key_type INTEGER NOT NULL,
  key TEXT NOT NULL,
  value BLOB NOT NULL,
  deleted_at DATETIME,
  seq INTEGER,
  UNIQUE(object_type, object_id, key)
);

CREATE TABLE "message_parts" (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  message_database_identifier INTEGER NOT NULL,
  mime_type TEXT NOT NULL,
  content BLOB,
  url TEXT,
  FOREIGN KEY(message_database_identifier) REFERENCES messages(database_identifier) ON DELETE CASCADE
);

CREATE TABLE "message_recipient_status" (
    database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    message_database_identifier INTEGER NOT NULL,
    user_id TEXT,
    status INTEGER NOT NULL,
    seq INTEGER,
    UNIQUE (message_database_identifier, user_id, status),
    FOREIGN KEY(message_database_identifier) REFERENCES messages(database_identifier) ON DELETE CASCADE
);

CREATE TABLE "messages" (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_at DATETIME,
  received_at DATETIME,
  deleted_at DATETIME,
  user_id TEXT NOT NULL,
  seq INTEGER,
  conversation_database_identifier INTEGER NOT NULL,
  event_database_identifier INTEGER UNIQUE,
  version INTEGER NOT NULL,
  object_identifier TEXT UNIQUE NOT NULL,
  message_index INTEGER,
  UNIQUE(conversation_database_identifier, seq),
  FOREIGN KEY(conversation_database_identifier) REFERENCES conversations(database_identifier) ON DELETE CASCADE,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE
);

CREATE TABLE schema_migrations (
  version INTEGER UNIQUE NOT NULL
);

CREATE TABLE "stream_members" (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  stream_database_identifier INTEGER NOT NULL,
  member_id TEXT NOT NULL,
  deleted_at DATETIME,
  seq INTEGER,
  UNIQUE (stream_database_identifier, member_id),
  FOREIGN KEY(stream_database_identifier) REFERENCES streams(database_identifier) ON DELETE CASCADE
);

CREATE TABLE "streams" (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  stream_id BLOB UNIQUE,
  seq INTEGER NOT NULL DEFAULT 0,
  client_seq INTEGER NOT NULL DEFAULT 0,
  version INTEGER, 
  client_id TEXT, 
  deleted_at DATETIME, 
  min_synced_seq INTEGER, 
  max_synced_seq INTEGER);

CREATE TABLE syncable_changes (
  change_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  row_identifier INTEGER NOT NULL,
  change_type INTEGER NOT NULL
);

CREATE TABLE synced_changes (
  change_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  row_identifier INTEGER NOT NULL,
  change_type INTEGER NOT NULL
);


CREATE INDEX conversation_participants_conversation_database_identifier_idx ON conversation_participants(conversation_database_identifier);

CREATE INDEX conversation_participants_deleted_at_idx ON conversation_participants(deleted_at);

CREATE INDEX conversation_participants_event_database_identifier_idx ON conversation_participants(event_database_identifier);

CREATE INDEX conversations_deleted_at_idx ON conversations(deleted_at);

CREATE INDEX conversations_stream_database_identifier_idx ON conversations(stream_database_identifier);

CREATE INDEX event_content_parts_event_database_identifier_idx ON event_content_parts(event_database_identifier);

CREATE INDEX event_metadata_event_database_identifier_idx ON event_metadata(event_database_identifier);

CREATE INDEX events_client_id_idx ON events(client_id);

CREATE INDEX events_seq_idx ON events(seq);

CREATE INDEX events_stream_database_identifier_idx ON events(stream_database_identifier);

CREATE INDEX message_parts_message_database_identifier_idx ON message_parts(message_database_identifier);

CREATE INDEX message_recipient_status_message_database_identifier_idx ON message_recipient_status(message_database_identifier);

CREATE INDEX messages_conversation_database_identifier_idx ON messages(conversation_database_identifier);

CREATE INDEX messages_deleted_at_idx ON messages(deleted_at);

CREATE INDEX messages_event_database_identifier_idx ON messages(event_database_identifier);

CREATE INDEX messages_message_index_idx ON messages(message_index);

CREATE INDEX stream_members_deleted_at_idx ON stream_members(deleted_at);

CREATE INDEX stream_members_stream_database_identifier_idx ON stream_members(stream_database_identifier);

CREATE INDEX streams_client_id_idx ON streams(client_id);

CREATE INDEX streams_deleted_at_idx ON streams(deleted_at);

CREATE INDEX synced_changes_table_name_idx ON synced_changes(table_name);


CREATE TRIGGER tombstone_duplicate_events_by_client_id 
AFTER INSERT ON events
FOR EACH ROW WHEN NEW.client_id IS NOT NULL
BEGIN
	UPDATE events SET type = 10 
	WHERE database_identifier = NEW.database_identifier
	AND (SELECT count(*) FROM events WHERE client_id = NEW.client_id) > 1;
END;

CREATE TRIGGER track_deletes_of_conversation_participants AFTER UPDATE OF deleted_at ON conversation_participants
WHEN NEW.seq IS OLD.seq AND (NEW.deleted_at NOT NULL AND OLD.deleted_at IS NULL)
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('conversation_participants', NEW.database_identifier, 2);
END;

CREATE TRIGGER track_deletes_of_conversations AFTER UPDATE OF deleted_at ON conversations
WHEN (NEW.deleted_at NOT NULL AND OLD.deleted_at IS NULL)
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('conversations', NEW.database_identifier, 2);
END;

CREATE TRIGGER track_deletes_of_keyed_values AFTER UPDATE OF deleted_at ON keyed_values
WHEN (NEW.deleted_at NOT NULL AND OLD.deleted_at IS NULL)
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('keyed_values', NEW.database_identifier, 2);
END;

CREATE TRIGGER track_deletes_of_messages AFTER UPDATE OF deleted_at ON messages
WHEN (NEW.deleted_at NOT NULL AND OLD.deleted_at IS NULL)
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('messages', NEW.database_identifier, 2);
END;

CREATE TRIGGER track_deletes_of_stream_members AFTER UPDATE OF deleted_at ON stream_members
WHEN NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL
BEGIN
  INSERT INTO synced_changes(table_name, row_identifier, change_type) VALUES ('stream_members', OLD._ROWID_, 2);
END;

CREATE TRIGGER track_deletes_of_streams AFTER UPDATE OF deleted_at ON streams
WHEN NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL
BEGIN
  INSERT INTO synced_changes(table_name, row_identifier, change_type) VALUES ('streams', OLD.database_identifier, 2);
END;

CREATE TRIGGER track_inserts_of_conversation_participants AFTER INSERT ON conversation_participants
WHEN NEW.stream_member_database_identifier IS NULL
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('conversation_participants', NEW.database_identifier, 0);
END;

CREATE TRIGGER track_inserts_of_conversations AFTER INSERT ON conversations
WHEN NEW.stream_database_identifier IS NULL
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('conversations', NEW.database_identifier, 0);
END;

CREATE TRIGGER track_inserts_of_events_delete
AFTER INSERT ON events FOR EACH ROW 
WHEN NEW.seq IS NOT NULL AND NEW.type = 9 AND NOT EXISTS (SELECT 1 FROM events WHERE client_id = NEW.client_id AND database_identifier != NEW.database_identifier)
BEGIN
  INSERT OR IGNORE INTO synced_changes(table_name, row_identifier, change_type) VALUES ('events', (SELECT database_identifier FROM events WHERE stream_database_identifier = NEW.stream_database_identifier AND seq = NEW.target_seq), 2);
  UPDATE events SET type = 10, subtype = NULL, external_content_id = NULL, member_id = NULL, target_seq = NULL, version = NULL WHERE database_identifier = (SELECT database_identifier FROM events WHERE stream_database_identifier = NEW.stream_database_identifier AND seq = NEW.target_seq);
END;

CREATE TRIGGER track_inserts_of_events_non_delete
AFTER INSERT ON events FOR EACH ROW 
WHEN NEW.seq IS NOT NULL AND NEW.type != 9 AND NOT EXISTS (SELECT 1 FROM events WHERE client_id = NEW.client_id AND database_identifier != NEW.database_identifier)
BEGIN
  INSERT INTO synced_changes(table_name, row_identifier, change_type) VALUES ('events', NEW.database_identifier, 0);
END;

CREATE TRIGGER track_inserts_of_keyed_values AFTER INSERT ON keyed_values
WHEN NEW.seq IS NULL
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('keyed_values', NEW.database_identifier, 0);
END;

CREATE TRIGGER track_inserts_of_stream_members AFTER INSERT ON stream_members
WHEN NEW.seq IS NOT NULL
BEGIN
  INSERT INTO synced_changes(table_name, row_identifier, change_type) VALUES ('stream_members', NEW._ROWID_, 0);
END;

CREATE TRIGGER track_inserts_of_streams AFTER INSERT ON streams
WHEN NEW.stream_id IS NOT NULL
BEGIN
  INSERT INTO synced_changes(table_name, row_identifier, change_type) VALUES ('streams', NEW.database_identifier, 0);
END;

CREATE TRIGGER track_message_send_on_insert AFTER INSERT ON messages
WHEN NEW.seq IS NULL
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('messages', NEW.database_identifier, 0);
END;

CREATE TRIGGER track_re_inserts_of_conversation_participants AFTER UPDATE OF deleted_at ON conversation_participants
WHEN NEW.seq IS NOT NULL AND NEW.seq = OLD.seq AND (NEW.deleted_at IS NULL AND OLD.deleted_at NOT NULL)
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('conversation_participants', NEW.database_identifier, 0);
END;

CREATE TRIGGER track_syncable_changes_for_message_receipts AFTER INSERT ON message_recipient_status
WHEN NEW.seq IS NULL
BEGIN
    INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('message_recipient_status', NEW.database_identifier, 0);
END;

CREATE TRIGGER track_updates_of_event_seqs AFTER UPDATE OF seq ON events
WHEN NEW.seq IS NOT NULL AND OLD.seq IS NULL
BEGIN
  INSERT INTO synced_changes(table_name, row_identifier, change_type) VALUES ('events', NEW.database_identifier, 1);
END;

CREATE TRIGGER track_updates_of_event_type_message_to_tombstone AFTER UPDATE OF type ON events
WHEN NEW.type = 10 AND OLD.type = 4
BEGIN
  DELETE FROM event_content_parts WHERE event_database_identifier = NEW.database_identifier;
  DELETE FROM event_metadata WHERE event_database_identifier = NEW.database_identifier;
END;

CREATE TRIGGER track_updates_of_keyed_values AFTER UPDATE OF value ON keyed_values
WHEN ((NEW.value NOT NULL AND OLD.value IS NULL) OR (NEW.value IS NULL AND OLD.value NOT NULL) OR (NEW.value != OLD.value))
BEGIN
  INSERT INTO syncable_changes(table_name, row_identifier, change_type) VALUES ('keyed_values', NEW.database_identifier, 1);
END;

CREATE TRIGGER track_updates_of_streams AFTER UPDATE OF stream_id ON streams
WHEN NEW.stream_id IS NOT NULL AND OLD.stream_id IS NULL
BEGIN
  INSERT INTO synced_changes(table_name, row_identifier, change_type) VALUES ('streams', NEW.database_identifier, 1);
END;



INSERT INTO schema_migrations (version) VALUES (20140628105322170);

INSERT INTO schema_migrations (version) VALUES (20140628114921198);

INSERT INTO schema_migrations (version) VALUES (20140701095427050);

INSERT INTO schema_migrations (version) VALUES (20140701114842931);

INSERT INTO schema_migrations (version) VALUES (20140701144934637);

INSERT INTO schema_migrations (version) VALUES (20140706185141044);

INSERT INTO schema_migrations (version) VALUES (20140707082435390);

INSERT INTO schema_migrations (version) VALUES (20140707175635814);

INSERT INTO schema_migrations (version) VALUES (20140708092626927);

INSERT INTO schema_migrations (version) VALUES (20140708154438053);

INSERT INTO schema_migrations (version) VALUES (20140709095453868);

INSERT INTO schema_migrations (version) VALUES (20140715104949748);

INSERT INTO schema_migrations (version) VALUES (20140717013309255);

INSERT INTO schema_migrations (version) VALUES (20140717021208447);

INSERT INTO schema_migrations (version) VALUES (20140806143305965);

INSERT INTO schema_migrations (version) VALUES (20140820112730372);

INSERT INTO schema_migrations (version) VALUES (20140919115201707);

INSERT INTO schema_migrations (version) VALUES (20141002091849299);

INSERT INTO schema_migrations (version) VALUES (20141002175255465);

INSERT INTO schema_migrations (version) VALUES (20141002175510495);

INSERT INTO schema_migrations (version) VALUES (20141006140917614);

INSERT INTO schema_migrations (version) VALUES (20141006202908488);

INSERT INTO schema_migrations (version) VALUES (20141007110138268);

INSERT INTO schema_migrations (version) VALUES (20141009125004707);

INSERT INTO schema_migrations (version) VALUES (20141009125010758);

INSERT INTO schema_migrations (version) VALUES (20141027152445461);