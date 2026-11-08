/// Raw storage behind the session. The session is stored as a JSON string;
/// only the transport differs per platform.
abstract interface class SessionStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
