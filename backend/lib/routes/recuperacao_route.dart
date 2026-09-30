import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:shelf/shelf.dart';

import '../config/database.dart';

Future<Response> recuperarSenha(Request request) async {
  try {
    final body = await request.readAsString();
    final dados = jsonDecode(body);

    final email = dados['email'];

    if (email == null || email.toString().trim().isEmpty) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'O email é obrigatório.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      SELECT id
      FROM usuarios
      WHERE email = :email
      LIMIT 1
      ''',
      {
        'email': email,
      },
    );

    if (resultado.rows.isEmpty) {
      return Response(
        404,
        body: jsonEncode({
          'erro': 'Email não encontrado.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final codigo = (100000 + Random().nextInt(900000)).toString();

    await database.pool.execute(
      '''
      UPDATE usuarios
      SET codigo_recuperacao = :codigo,
          codigo_expira_em = DATE_ADD(NOW(), INTERVAL 10 MINUTE)
      WHERE email = :email
      ''',
      {
        'codigo': codigo,
        'email': email,
      },
    );

    return Response.ok(
      jsonEncode({
        'mensagem': 'Código de recuperação gerado.',
        'codigo': codigo,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao recuperar senha.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> redefinirSenha(Request request) async {
  try {
    final body = await request.readAsString();
    final dados = jsonDecode(body);

    final email = dados['email'];
    final codigo = dados['codigo'];
    final novaSenha = dados['novaSenha'];

    if (email == null ||
        codigo == null ||
        novaSenha == null ||
        email.toString().trim().isEmpty ||
        codigo.toString().trim().isEmpty ||
        novaSenha.toString().isEmpty) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'Email, código e nova senha são obrigatórios.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    if (novaSenha.toString().length < 6) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'A nova senha deve ter pelo menos 6 caracteres.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      SELECT id
      FROM usuarios
      WHERE email = :email
        AND codigo_recuperacao = :codigo
        AND codigo_expira_em > NOW()
      LIMIT 1
      ''',
      {
        'email': email,
        'codigo': codigo,
      },
    );

    if (resultado.rows.isEmpty) {
      return Response(
        401,
        body: jsonEncode({
          'erro': 'Código inválido ou expirado.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final senhaHash = BCrypt.hashpw(
      novaSenha.toString(),
      BCrypt.gensalt(),
    );

    await database.pool.execute(
      '''
      UPDATE usuarios
      SET senha = :senha,
          codigo_recuperacao = NULL,
          codigo_expira_em = NULL
      WHERE email = :email
      ''',
      {
        'senha': senhaHash,
        'email': email,
      },
    );

    return Response.ok(
      jsonEncode({
        'mensagem': 'Senha alterada com sucesso.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao redefinir senha.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}