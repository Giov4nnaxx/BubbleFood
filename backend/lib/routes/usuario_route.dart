import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/database.dart';

import 'package:bcrypt/bcrypt.dart';

Future<Response> listarUsuarios(Request request) async {
  try {
    final database = Database();

    final resultado = await database.pool.execute(
      '''
      SELECT
        id,
        nome,
        email,
        username,
        bio,
        avatar,
        criado_em
      FROM usuarios
      ORDER BY criado_em DESC
      ''',
    );

    final usuarios = resultado.rows.map((row) {
      return {
        'id': row.colByName('id'),
        'nome': row.colByName('nome'),
        'email': row.colByName('email'),
        'username': row.colByName('username'),
        'bio': row.colByName('bio'),
        'avatar': row.colByName('avatar'),
        'criado_em': row.colByName('criado_em'),
      };
    }).toList();

    return Response.ok(
      jsonEncode({
        'usuarios': usuarios,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO LISTAR USUARIOS: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao buscar usuários.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> buscarUsuario(Request request) async {
  try {
    final id = request.params['id'];

    if (id == null || int.tryParse(id) == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'ID do usuário inválido.',
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
        id,
        nome,
        email,
        username,
        bio,
        avatar,
        criado_em
      FROM usuarios
      WHERE id = :id
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
          'erro': 'Usuário não encontrado.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final row = resultado.rows.first;

    final usuario = {
      'id': row.colByName('id'),
      'nome': row.colByName('nome'),
      'email': row.colByName('email'),
      'username': row.colByName('username'),
      'bio': row.colByName('bio'),
      'avatar': row.colByName('avatar'),
      'criado_em': row.colByName('criado_em'),
    };

    return Response.ok(
      jsonEncode(usuario),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO BUSCAR USUARIO: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao buscar usuário.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> cadastrarUsuario(Request request) async {
  try {
    final body = await request.readAsString();
    final dados = jsonDecode(body);

    final nome = dados['nome'];
    final email = dados['email'];
    final username = dados['username'];
    final senha = dados['senha'];

    if (nome == null || email == null || username == null || senha == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'Todos os campos são obrigatórios.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final senhaHash = BCrypt.hashpw(
      senha.toString(),
      BCrypt.gensalt(),
    );

    await database.pool.execute(
      '''
  INSERT INTO usuarios
  (nome, email, username, senha)
  VALUES (:nome, :email, :username, :senha)
  ''',
      {
        'nome': nome,
        'email': email,
        'username': username,
        'senha': senhaHash,
      },
    );

    return Response(
      201,
      body: jsonEncode({
        'mensagem': 'Usuário cadastrado com sucesso.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao cadastrar usuário.',
        'detalhes': e.toString(),
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> atualizarUsuario(Request request) async {
  try {
    final id = request.params['id'];

    if (id == null || int.tryParse(id) == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'ID do usuário inválido.',
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

    if (int.parse(id) != int.parse(usuarioId.toString())) {
      return Response(
        403,
        body: jsonEncode({
          'erro': 'Você não pode alterar o perfil de outro usuário.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final dados = jsonDecode(await request.readAsString());

    final nome = dados['nome'];
    final username = dados['username'];
    final bio = dados['bio'];
    final avatar = dados['avatar'];

    if (nome == null || username == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'Nome e username são obrigatórios.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    late final dynamic resultado;

    try {
      resultado = await database.pool.execute(
        '''
    UPDATE usuarios
    SET
      nome = :nome,
      username = :username,
      bio = :bio,
      avatar = :avatar
    WHERE id = :id
    ''',
        {
          'id': int.parse(id),
          'nome': nome,
          'username': username,
          'bio': bio,
          'avatar': avatar,
        },
      );
    } catch (e) {
      if (e.toString().contains('[1062]')) {
        return Response(
          409,
          body: jsonEncode({
            'erro': 'Este username já está sendo usado.',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }

      rethrow;
    }

    if (resultado.affectedRows.toInt() == 0) {
      return Response(
        404,
        body: jsonEncode({
          'erro': 'Usuário não encontrado.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    return Response.ok(
      jsonEncode({
        'mensagem': 'Perfil atualizado com sucesso.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO ATUALIZAR USUARIO: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao atualizar perfil.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}

Future<Response> excluirUsuario(Request request) async {
  try {
    final id = request.params['id'];

    if (id == null || int.tryParse(id) == null) {
      return Response(
        400,
        body: jsonEncode({
          'erro': 'ID do usuário inválido.',
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

    if (int.parse(id) != int.parse(usuarioId.toString())) {
      return Response(
        403,
        body: jsonEncode({
          'erro': 'Você não pode excluir outro usuário.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    final database = Database();

    final resultado = await database.pool.execute(
      '''
      DELETE FROM usuarios
      WHERE id = :id
      ''',
      {
        'id': int.parse(id),
      },
    );

    if (resultado.affectedRows.toInt() == 0) {
      return Response(
        404,
        body: jsonEncode({
          'erro': 'Usuário não encontrado.',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    return Response.ok(
      jsonEncode({
        'mensagem': 'Usuário excluído com sucesso.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  } catch (e) {
    print('ERRO AO EXCLUIR USUARIO: $e');

    return Response(
      500,
      body: jsonEncode({
        'erro': 'Erro ao excluir usuário.',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );
  }
}
