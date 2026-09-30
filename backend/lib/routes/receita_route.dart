import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/database.dart';

Future<Response> listarReceitas(Request request) async {
  try {
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
      FROM receitas r
      INNER JOIN usuarios u ON u.id = r.usuario_id
      ORDER BY r.criado_em DESC
      ''',
    );

    final receitas = resultado.rows.map((row) {
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
        'receitas': receitas,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao buscar receitas.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> buscarReceita(Request request) async {
  try {
    final id = request.params['id'];

    if (id == null || int.tryParse(id) == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'ID da receita inválido.',
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
      FROM receitas r
      INNER JOIN usuarios u ON u.id = r.usuario_id
      WHERE r.id = :id
      LIMIT 1
      ''',
      {
        'id': int.parse(id),
      },
    );

    if (resultado.rows.isEmpty) {
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

    final row = resultado.rows.first;

    final receita = {
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

    return Response.ok(
      jsonEncode(receita),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO BUSCAR RECEITA: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao buscar receita.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> atualizarReceita(Request request) async {
  try {
    final id = request.params['id'];

    if (id == null || int.tryParse(id) == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'ID da receita inválido.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

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

    final dados = jsonDecode(await request.readAsString());

    final titulo = dados['titulo'];
    final descricao = dados['descricao'];
    final ingredientes = dados['ingredientes'];
    final modoPreparo = dados['modo_preparo'];
    final tempoPreparo = dados['tempo_preparo'];
    final imagem = dados['imagem'];

    if (usuarioId == null ||
        titulo == null ||
        ingredientes == null ||
        modoPreparo == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'Preencha os campos obrigatórios.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      UPDATE receitas
      SET
        titulo = :titulo,
        descricao = :descricao,
        ingredientes = :ingredientes,
        modo_preparo = :modo_preparo,
        tempo_preparo = :tempo_preparo,
        imagem = :imagem
      WHERE id = :id
        AND usuario_id = :usuario_id
      ''',
      {
        'id': int.parse(id),
        'usuario_id': usuarioId,
        'titulo': titulo,
        'descricao': descricao,
        'ingredientes': ingredientes,
        'modo_preparo': modoPreparo,
        'tempo_preparo': tempoPreparo,
        'imagem': imagem,
      },
    );

    if (resultado.affectedRows.toInt() == 0) {
      return Response(
        404,
        body: jsonEncode({
          'erro': 'Receita não encontrada ou você não é o proprietário.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    return Response.ok(
      jsonEncode({
        'mensagem': 'Receita atualizada com sucesso.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO ATUALIZAR RECEITA: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao atualizar receita.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> cadastrarReceita(Request request) async {
  try {
    final dados = jsonDecode(await request.readAsString());

    final usuarioId = request.context['usuario_id'];
    final titulo = dados['titulo'];
    final descricao = dados['descricao'];
    final ingredientes = dados['ingredientes'];
    final modoPreparo = dados['modo_preparo'];
    final tempoPreparo = dados['tempo_preparo'];
    final imagem = dados['imagem'];

    if (usuarioId == null ||
        titulo == null ||
        ingredientes == null ||
        modoPreparo == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'Preencha os campos obrigatórios.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      INSERT INTO receitas
      (
        usuario_id,
        titulo,
        descricao,
        ingredientes,
        modo_preparo,
        tempo_preparo,
        imagem
      )
      VALUES
      (
        :usuario_id,
        :titulo,
        :descricao,
        :ingredientes,
        :modo_preparo,
        :tempo_preparo,
        :imagem
      )
      ''',
      {
        'usuario_id': usuarioId,
        'titulo': titulo,
        'descricao': descricao,
        'ingredientes': ingredientes,
        'modo_preparo': modoPreparo,
        'tempo_preparo': tempoPreparo,
        'imagem': imagem,
      },
    );

    return Response(
      201,
      body: jsonEncode({
        'mensagem': 'Receita cadastrada com sucesso.',
        'id': resultado.lastInsertID.toInt(),
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao cadastrar receita.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> excluirReceita(Request request) async {
  try {
    final id = request.params['id'];

    if (id == null || int.tryParse(id) == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'ID da receita inválido.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

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
      DELETE FROM receitas
      WHERE id = :id
        AND usuario_id = :usuario_id
      ''',
      {
        'id': int.parse(id),
        'usuario_id': usuarioId,
      },
    );

    if (resultado.affectedRows.toInt() == 0) {
      return Response(
        404,
        body: jsonEncode({
          'erro': 'Receita não encontrada ou você não é o proprietário.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    return Response.ok(
      jsonEncode({
        'mensagem': 'Receita excluída com sucesso.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO EXCLUIR RECEITA: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao excluir receita.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}
