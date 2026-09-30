import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/database.dart';

Middleware verificarToken() {
  return (Handler handler) {
    return (Request request) async {
      try {
        final authorization = request.headers['authorization'];

        if (authorization == null || authorization.isEmpty) {
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

        if (!authorization.startsWith('Bearer ')) {
          return Response(
            401,
            body: jsonEncode({
              'erro': 'Formato do token inválido.',
            }),
            headers: {
              'Content-Type': 'application/json',
            },
          );
        }

        final token = authorization.substring(7);

        if (token.isEmpty) {
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

        final database = Database();

        final resultado = await database.pool.execute(
          '''
          SELECT usuario_id
          FROM sessoes
          WHERE token = :token
          LIMIT 1
          ''',
          {
            'token': token,
          },
        );

        if (resultado.rows.isEmpty) {
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

        final usuarioId = resultado.rows.first.colByName('usuario_id');

        final requestAutenticada = request.change(
          context: {
            'usuario_id': usuarioId,
          },
        );

        return await handler(requestAutenticada);
      } catch (e) {
        print('ERRO AO VALIDAR TOKEN: $e');

        return Response(
          500,
          body: jsonEncode({
            'erro': 'Erro ao validar token.',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }
    };
  };
}