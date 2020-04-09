import 'package:dependencies/dependencies.dart';
import 'package:mooncake/usecases/posts/posts.dart';
import 'package:mooncake/usecases/usecases.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifications/notifications_repository_impl.dart';
import 'posts/posts_repository_impl.dart';
import 'user/user_repository_impl.dart';
import 'settings/settings_repository_impl.dart';

/// Represents the module that is used during dependency injection
/// to provide repositories instances.
class RepositoriesModule implements Module {
  @override
  void configure(Binder binder) {
    binder
      ..bindLazySingleton<NotificationsRepository>(
          (injector, params) => NotificationsRepositoryImpl(
                localNotificationsSource: injector.get(),
                remoteNotificationsSource: injector.get(),
              ))
      ..bindLazySingleton<PostsRepository>(
          (injector, params) => PostsRepositoryImpl(
                localSource: injector.get(),
                remoteSource: injector.get(),
              ))
      ..bindLazySingleton<SettingsRepository>(
          (injector, params) => SettingsRepositoryImpl(
                sharedPreferences: SharedPreferences.getInstance(),
              ))
      ..bindLazySingleton<UserRepository>(
          (injector, params) => UserRepositoryImpl(
                localUserSource: injector.get(),
                remoteUserSource: injector.get(),
              ));
  }
}