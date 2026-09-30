import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/database.dart';

Future<Response> logout(Request request) async {
  try {
    final authorization = request.headers['authorization'];

    if (authorization == null ||
        !authorization.startsWith('Bearer ')) {
      return Response(
        401,
        body: jsonEncode({
          'erro': 'Token não informado.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final token = authorization.substring(7);

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      DELETE FROM sessoes
      WHERE token = :token
      ''',
      {
        'token': token,
      },
    );

    if (resultado.affectedRows.toInt() == 0) {
      return Response(
        401,
        body: jsonEncode({
          'erro': 'Token inválido.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    return Response.ok(
      jsonEncode({
        'mensagem': 'Logout realizado com sucesso.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO REALIZAR LOGOUT: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao realizar logout.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}