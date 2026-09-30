import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/database.dart';

import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';

import 'dart:math';

Future<Response> login(Request request) async {
  try {
    final body = await request.readAsString();
    final dados = jsonDecode(body);

    final login = dados['login'];
    final senha = dados['senha'];

    if (login == null ||
        login.toString().trim().isEmpty ||
        senha == null ||
        senha.toString().isEmpty) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'Usuário/email e senha são obrigatórios.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      SELECT id, nome, email, username, senha, bio, avatar
      FROM usuarios
      WHERE email = :login OR username = :login
      LIMIT 1
      ''',
      {
        'login': login,
      },
    );

    if (resultado.rows.isEmpty) {
      return Response(
        401,
        body: jsonEncode({
          'erro': 'Usuário/email ou senha inválidos.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final usuario = resultado.rows.first;

    final senhaBanco = usuario.colByName('senha');

    if (!BCrypt.checkpw(senha.toString(), senhaBanco)) {
      return Response(
        401,
        body: jsonEncode({
          'erro': 'Usuário/email ou senha inválidos.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final random = Random.secure();

    final valores = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    );

    final token = sha256.convert(valores).toString();

    await database.pool.execute(
      '''
  INSERT INTO sessoes
  (usuario_id, token)
  VALUES
  (:usuario_id, :token)
  ''',
      {
        'usuario_id': usuario.colByName('id'),
        'token': token,
      },
    );

    return Response.ok(
      jsonEncode({
        'mensagem': 'Login realizado com sucesso.',
        'token': token,
        'usuario': {
          'id': usuario.colByName('id'),
          'nome': usuario.colByName('nome'),
          'email': usuario.colByName('email'),
          'username': usuario.colByName('username'),
          'bio': usuario.colByName('bio'),
          'avatar': usuario.colByName('avatar'),
        },
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao realizar login.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}
