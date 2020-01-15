import 'package:dependencies/dependencies.dart';
import 'package:mooncake/usecases/usecases.dart';

class UseCaseModule implements Module {
  @override
  void configure(Binder binder) {
    binder
      // Login use cases
      ..bindFactory((injector, params) => CheckLoginUseCase(
            walletRepository: injector.get(),
          ))
      ..bindFactory((injector, params) => LogoutUseCase(
            walletRepository: injector.get(),
          ))
      // Mnemonic use cases
      ..bindFactory((injector, params) => GenerateMnemonicUseCase())
      // Posts use cases
      ..bindFactory((injector, params) => GetUserReactionsToPost(
            walletRepository: injector.get(),
            postsRepository: injector.get(),
          ))
      ..bindFactory((injector, params) => CreatePostUseCase(
            walletRepository: injector.get(),
            postsRepository: injector.get(),
          ))
      ..bindFactory((injector, params) => FetchPostsUseCase(
            repository: injector.get(),
          ))
      ..bindFactory((injector, params) => GetCommentsUseCase(
            postsRepository: injector.get(),
          ))
      ..bindFactory((injector, params) => GetPostsUseCase(
            postsRepository: injector.get(),
          ))
      ..bindFactory((injector, params) => AddPostReactionUseCase(
            postsRepository: injector.get(),
            walletRepository: injector.get(),
          ))
      ..bindFactory((injector, params) => SyncPostsUseCase(
            postsRepository: injector.get(),
          ))
      ..bindFactory((injector, params) => RemoveReactionFromPostUseCase(
            postsRepository: injector.get(),
            walletRepository: injector.get(),
          ))
      // Wallet use cases
      ..bindFactory((injector, params) => GetAddressUseCase(
            walletRepository: injector.get(),
          ))
      ..bindFactory((injector, params) => SaveWalletUseCase(
            walletRepository: injector.get(),
          ));
  }
}
