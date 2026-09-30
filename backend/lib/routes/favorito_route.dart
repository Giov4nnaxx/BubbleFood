import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/database.dart';

Future<Response> listarFavoritos(Request request) async {
  try {
    final usuarioId = request.context['usuario_id'];

    if (usuarioId == null) {
      return Response(
        401,
        body: jsonEncode({
          'erro': 'Usuário não autenticado.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      SELECT
        r.id,
        r.titulo,
        r.descricao,
        r.ingredientes,
        r.modo_preparo,
        r.tempo_preparo,
        r.imagem,
        r.criado_em,
        u.id AS usuario_id,
        u.nome AS usuario_nome,
        u.username AS usuario_username
      FROM favoritos f
      INNER JOIN receitas r
        ON r.id = f.receita_id
      INNER JOIN usuarios u
        ON u.id = r.usuario_id
      WHERE f.usuario_id = :usuario_id
      ORDER BY f.criado_em DESC
      ''',
      {
        'usuario_id': usuarioId,
      },
    );

    final favoritos = resultado.rows.map((row) {
      return {
        'id': row.colByName('id'),
        'titulo': row.colByName('titulo'),
        'descricao': row.colByName('descricao'),
        'ingredientes': row.colByName('ingredientes'),
        'modo_preparo': row.colByName('modo_preparo'),
        'tempo_preparo': row.colByName('tempo_preparo'),
        'imagem': row.colByName('imagem'),
        'criado_em': row.colByName('criado_em'),
        'usuario': {
          'id': row.colByName('usuario_id'),
          'nome': row.colByName('usuario_nome'),
          'username': row.colByName('usuario_username'),
        },
      };
    }).toList();

    return Response.ok(
      jsonEncode({
        'favoritos': favoritos,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO LISTAR FAVORITOS: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao buscar favoritos.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> favoritarReceita(Request request) async {
  try {
    final dados = jsonDecode(await request.readAsString());

    final usuarioId = request.context['usuario_id'];
    final receitaId = dados['receita_id'];

    if (usuarioId == null || receitaId == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'Informe o receita_id.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final receita = await database.pool.execute(
      '''
      SELECT id
      FROM receitas
      WHERE id = :receita_id
      LIMIT 1
      ''',
      {
        'receita_id': receitaId,
      },
    );

    if (receita.rows.isEmpty) {
      return Response(
        404,
        body: jsonEncode({
          'erro': 'Receita não encontrada.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    try {
      await database.pool.execute(
        '''
        INSERT INTO favoritos
        (usuario_id, receita_id)
        VALUES
        (:usuario_id, :receita_id)
        ''',
        {
          'usuario_id': usuarioId,
          'receita_id': receitaId,
        },
      );
    } catch (e) {
      if (e.toString().contains('Duplicate')) {
        return Response(
          409,
          body: jsonEncode({
            'erro': 'Essa receita já está nos favoritos.',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }

      rethrow;
    }

    return Response(
      201,
      body: jsonEncode({
        'mensagem': 'Receita adicionada aos favoritos.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO FAVORITAR RECEITA: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao favoritar receita.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> desfavoritarReceita(Request request) async {
  try {
    final dados = jsonDecode(await request.readAsString());

    final usuarioId = request.context['usuario_id'];
    final receitaId = dados['receita_id'];

    if (usuarioId == null || receitaId == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'Informe o receita_id.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      DELETE FROM favoritos
      WHERE usuario_id = :usuario_id
        AND receita_id = :receita_id
      ''',
      {
        'usuario_id': usuarioId,
        'receita_id': receitaId,
      },
    );

    if (resultado.affectedRows.toInt() == 0) {
      return Response(
        404,
        body: jsonEncode({
          'erro': 'Essa receita não está nos favoritos.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    return Response.ok(
      jsonEncode({
        'mensagem': 'Receita removida dos favoritos.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO DESFAVORITAR RECEITA: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao remover receita dos favoritos.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}
