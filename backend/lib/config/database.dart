import 'package:mysql_dart/mysql_client.dart';

class Database {
  static final Database _instance = Database._internal();

  factory Database() {
    return _instance;
  }

  Database._internal();

  late MySQLConnectionPool pool;

  Future<void> connect() async {
    pool = MySQLConnectionPool(
      host: '127.0.0.1',
      port: 3306,
      userName: 'root',
      password: 'senai2026',
      databaseName: 'bubblefood',
      maxConnections: 5,
    );

    await pool.execute('SELECT 1');

    print('Banco de dados conectado!');
  }
}