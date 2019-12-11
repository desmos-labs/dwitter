import 'package:dependencies/dependencies.dart';
import 'package:dwitter/repositories/repositories.dart';
import 'package:dwitter/sources/sources.dart';
import 'package:http/http.dart' as http;
import 'package:sacco/sacco.dart';

class SourcesModule implements Module {
  // TODO: Change this to real RPC endpoints
  static const _lcdUrl = "http://10.0.2.2:1317";
  static const _rpcUrl = "ws://10.0.2.2:26657";
  final _networkInfo = NetworkInfo(bech32Hrp: "desmos", lcdUrl: _lcdUrl);

  @override
  void configure(Binder binder) {
    binder
      ..bindLazySingleton<WalletSource>(
        (injector, params) => WalletSourceImpl(
          networkInfo: _networkInfo,
        ),
      )
      ..bindLazySingleton<LocalPostsSource>(
        (injector, params) => LocalPostsSourceImpl(
          walletSource: injector.get(),
        ),
        name: "local",
      )
      ..bindLazySingleton<RemotePostsSource>(
        (injector, params) => RemotePostsSourceImpl(
          rpcEndpoint: _rpcUrl,
          chainHelper: ChainHelper(
            lcdEndpoint: _lcdUrl,
            httpClient: http.Client(),
          ),
          walletSource: injector.get(),
        ),
        name: "remote",
      );
  }
}
