import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../lib/middleware/auth_middleware.dart';

import '../lib/routes/usuario_route.dart';
import '../lib/routes/login_route.dart';
import '../lib/routes/recuperacao_route.dart';
import '../lib/routes/receita_route.dart';
import '../lib/routes/favorito_route.dart';
import '../lib/routes/logout_route.dart';

import '../lib/config/database.dart';

void main() async {
  final database = Database();

  try {
    await database.connect();

    final router = Router();

    router.get('/health', (Request request) {
      return Response.ok(
        'BubbleFood API funcionando!',
      );
    });

    router.get('/usuarios', listarUsuarios);
    router.get(
      '/usuarios/<id>',
      Pipeline().addMiddleware(verificarToken()).addHandler(buscarUsuario),
    );

    router.put(
      '/usuarios/<id>',
      Pipeline().addMiddleware(verificarToken()).addHandler(atualizarUsuario),
    );
    router.post('/cadastro', cadastrarUsuario);
    router.post('/login', login);
    router.delete(
      '/usuarios/<id>',
      Pipeline().addMiddleware(verificarToken()).addHandler(excluirUsuario),
    );

    router.post('/recuperar-senha', recuperarSenha);
    router.post('/redefinir-senha', redefinirSenha);

    router.get(
      '/favoritos',
      Pipeline().addMiddleware(verificarToken()).addHandler(listarFavoritos),
    );

    router.post(
      '/favoritos',
      Pipeline().addMiddleware(verificarToken()).addHandler(favoritarReceita),
    );

    router.delete(
      '/favoritos',
      Pipeline()
          .addMiddleware(verificarToken())
          .addHandler(desfavoritarReceita),
    );

    router.get(
      '/receitas',
      Pipeline().addMiddleware(verificarToken()).addHandler(listarReceitas),
    );

    router.get(
      '/receitas/<id>',
      Pipeline().addMiddleware(verificarToken()).addHandler(buscarReceita),
    );

    router.post(
      '/receitas',
      Pipeline().addMiddleware(verificarToken()).addHandler(cadastrarReceita),
    );

    router.put(
      '/receitas/<id>',
      Pipeline().addMiddleware(verificarToken()).addHandler(atualizarReceita),
    );

    router.delete(
      '/receitas/<id>',
      Pipeline().addMiddleware(verificarToken()).addHandler(excluirReceita),
    );

    router.post(
      '/logout',
      Pipeline().addMiddleware(verificarToken()).addHandler(logout),
    );

    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    final server = await shelf_io.serve(
      handler,
      'localhost',
      8080,
    );

    print('');
    print('BubbleFood Backend iniciado!');
    print('http://localhost:8080');
    print('');
  } catch (e) {
    print('Erro ao iniciar o servidor: $e');
  }
}
