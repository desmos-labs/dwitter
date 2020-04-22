import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:meta/meta.dart';
import 'package:mooncake/dependency_injection/dependency_injection.dart';
import 'package:mooncake/entities/entities.dart';
import 'package:mooncake/usecases/usecases.dart';

import '../export.dart';

/// Implementation of [Bloc] that allows to properly deal with
/// events and states related to the list of posts.
class PostsListBloc extends Bloc<PostsListEvent, PostsListState> {
  static const _HOME_LIMIT = 50;

  // Synchronization
  final int _syncPeriod;
  final SyncPostsUseCase _syncPostsUseCase;
  Timer _syncTimer;

  // Use cases
  final GetHomePostsUseCase _getHomePostsUseCase;
  final GetHomeEventsUseCase _getHomeEventsUseCase;
  final UpdatePostsStatusUseCase _updatePostsStatusUseCase;
  final ManagePostReactionsUseCase _managePostReactionsUseCase;
  final HidePostUseCase _hidePostUseCase;

  // Subscriptions
  StreamSubscription _eventsSubscription;
  StreamSubscription _postsSubscription;
  StreamSubscription _txSubscription;

  PostsListBloc({
    @required int syncPeriod,
    @required FirebaseAnalytics analytics,
    @required GetHomePostsUseCase getHomePostsUseCase,
    @required GetHomeEventsUseCase getHomeEventsUseCase,
    @required SyncPostsUseCase syncPostsUseCase,
    @required GetNotificationsUseCase getNotificationsUseCase,
    @required UpdatePostsStatusUseCase updatePostsStatusUseCase,
    @required ManagePostReactionsUseCase managePostReactionsUseCase,
    @required HidePostUseCase hidePostUseCase,
  })  : _syncPeriod = syncPeriod,
        assert(getHomePostsUseCase != null),
        _getHomePostsUseCase = getHomePostsUseCase,
        assert(getHomeEventsUseCase != null),
        _getHomeEventsUseCase = getHomeEventsUseCase,
        assert(syncPostsUseCase != null),
        _syncPostsUseCase = syncPostsUseCase,
        assert(updatePostsStatusUseCase != null),
        _updatePostsStatusUseCase = updatePostsStatusUseCase,
        assert(managePostReactionsUseCase != null),
        _managePostReactionsUseCase = managePostReactionsUseCase,
        assert(hidePostUseCase != null),
        _hidePostUseCase = hidePostUseCase {
    _initializeSyncTimer();

    // Subscribe to the posts changes
    _listToHomePosts(_HOME_LIMIT);

    // Subscribe to tell the user he should refresh
    _eventsSubscription = _getHomeEventsUseCase.stream.listen((event) {
      add(ShouldRefreshPosts());
    });

    // Subscribe to the transactions notifications
    _txSubscription = getNotificationsUseCase.stream().listen((notification) {
      if (notification is TxSuccessfulNotification) {
        add(TxSuccessful(txHash: notification.txHash));
      } else if (notification is TxFailedNotification) {
        add(TxFailed(txHash: notification.txHash, error: notification.error));
      }
    });
  }

  factory PostsListBloc.create({int syncPeriod = 30}) {
    return PostsListBloc(
      syncPeriod: syncPeriod,
      getHomePostsUseCase: Injector.get(),
      getHomeEventsUseCase: Injector.get(),
      syncPostsUseCase: Injector.get(),
      analytics: Injector.get(),
      getNotificationsUseCase: Injector.get(),
      updatePostsStatusUseCase: Injector.get(),
      managePostReactionsUseCase: Injector.get(),
      hidePostUseCase: Injector.get(),
    );
  }

  @override
  PostsListState get initialState => PostsLoading();

  @override
  Stream<PostsListState> transformEvents(
    Stream<PostsListEvent> events,
    Function next,
  ) {
    return super.transformEvents(events.distinct(), next);
  }

  @override
  Stream<PostsListState> mapEventToState(PostsListEvent event) async* {
    final currentState = state;
    if (event is PostsUpdated) {
      yield* _mapPostsUpdatedEventToState(event);
    } else if (event is AddOrRemoveLike) {
      yield* _convertAddOrRemoveLikeEvent(event);
    } else if (event is AddOrRemovePostReaction) {
      yield* _mapAddPostReactionEventToState(event);
    } else if (event is HidePost) {
      yield* _mapHidePostEventToState(event);
    } else if (event is SyncPosts) {
      yield* _mapSyncPostsListEventToState();
    } else if (event is SyncPostsCompleted) {
      yield* _mapSyncPostsCompletedEventToState();
    } else if (event is ShouldRefreshPosts) {
      yield* _mapShouldRefreshPostsEventToState();
    } else if (event is RefreshPosts) {
      yield* _refreshPostsEventToState();
    } else if (event is FetchPosts && !_hasReachedMax(currentState)) {
      yield* _mapFetchEventToState();
    } else if (event is TxSuccessful) {
      _handleTxSuccessfulEvent(event);
    } else if (event is TxFailed) {
      _handleTxFailedEvent(event);
    }
  }

  void _listToHomePosts(int limit) {
    _postsSubscription?.cancel();
    _postsSubscription = _getHomePostsUseCase.stream(limit).listen((posts) {
      if (posts.isEmpty) return;
      add(PostsUpdated(posts));
    });
  }

  bool _hasReachedMax(PostsListState state) {
    return state is PostsLoaded && state.hasReachedMax;
  }

  /// Initializes the timer allowing us to sync the user activity once every
  /// [syncPeriod] seconds if it hasn't been done before.
  void _initializeSyncTimer() {
    if (_syncTimer?.isActive != true) {
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(Duration(seconds: _syncPeriod), (t) {
        add(SyncPosts());
      });
    }
  }

  /// Merges the [current] posts list with the [newList].
  /// INVARIANT: `current.length > newList.length`
  List<Post> _mergePosts(List<Post> current, List<Post> newList) {
    return current.map((post) {
      final newPost = newList.firstWhere(
        (p) => p.id == post.id,
        orElse: () => null,
      );
      return newPost != null ? newPost : post;
    });
  }

  /// Handles the event emitted when a new list of posts has been emitted.
  Stream<PostsListState> _mapPostsUpdatedEventToState(
    PostsUpdated event,
  ) async* {
    final currentState = state;
    if (currentState is PostsLoading) {
      yield PostsLoaded.first(posts: event.posts);
    } else if (currentState is PostsLoaded) {
      // Avoid overloading operations
      if (currentState.posts == event.posts) {
        return;
      }

      yield currentState.copyWith(
        posts: event.posts.length < currentState.posts.length
            ? _mergePosts(currentState.posts, event.posts)
            : event.posts,
        refreshing: false,
        shouldRefresh: false,
      );
    }
  }

  /// Converts an [AddOrRemoveLikeEvent] into an
  /// [AddOrRemovePostReaction] event so that it can be handled properly.
  Stream<PostsListState> _convertAddOrRemoveLikeEvent(
    AddOrRemoveLike event,
  ) {
    final reactEvent = AddOrRemovePostReaction(
      event.post,
      Constants.LIKE_REACTION,
    );
    return _mapAddPostReactionEventToState(reactEvent);
  }

  /// Handles the event emitted when the user likes a post
  Stream<PostsListState> _mapAddPostReactionEventToState(
    AddOrRemovePostReaction event,
  ) async* {
    final currentState = state;
    if (currentState is PostsLoaded) {
      final newPost = await _managePostReactionsUseCase.addOrRemove(
        post: event.post,
        reaction: event.reactionCode,
      );
      final posts = currentState.posts
          .map((post) => post.id == newPost.id ? newPost : post)
          .toList();
      yield currentState.copyWith(posts: posts);
    }
  }

  /// Handles the event emitted when a post should be hidden from the user view.
  Stream<PostsListState> _mapHidePostEventToState(
    HidePost event,
  ) async* {
    final currentState = state;
    if (currentState is PostsLoaded) {
      final newPost = await _hidePostUseCase.hide(event.post);
      final newPosts = currentState.posts
          .map((post) => post.id == newPost.id ? newPost : post)
          .toList();
      yield currentState.copyWith(posts: newPosts);
    }
  }

  Stream<PostsListState> _mapFetchEventToState() async* {
    final currentState = state;
    if (currentState is PostsLoading) {
      final posts = await _getHomePostsUseCase.refresh(
        start: 0,
        limit: _HOME_LIMIT,
      );
      yield PostsLoaded.first(posts: posts);
    } else if (currentState is PostsLoaded) {
      final posts = await _getHomePostsUseCase.refresh(
        start: currentState.posts.length,
        limit: _HOME_LIMIT,
      );
      yield posts.isEmpty
          ? currentState.copyWith(hasReachedMax: true)
          : currentState.copyWith(
              posts: currentState.posts + posts,
              hasReachedMax: false,
            );

      // Listen to new changes on all the posts
      if (posts.isNotEmpty) {
        _listToHomePosts(currentState.posts.length + posts.length);
      }
    }
  }

  /// Handles the event that is emitted when the list of posts should be
  /// refreshed.
  Stream<PostsListState> _mapShouldRefreshPostsEventToState() async* {
    final currentState = state;
    if (currentState is PostsLoaded) {
      yield currentState.copyWith(shouldRefresh: true);
    }
  }

  /// Handles the event emitted when the list of the home posts
  /// should be updated.
  Stream<PostsListState> _refreshPostsEventToState() async* {
    final currentState = state;
    int limit = _HOME_LIMIT;
    if (currentState is PostsLoaded) {
      limit = currentState.posts.length;
      yield currentState.copyWith(refreshing: true, shouldRefresh: false);
    }

    final posts = await _getHomePostsUseCase.refresh(start: 0, limit: limit);
    if (currentState is PostsLoaded) {
      yield currentState.copyWith(refreshing: false, posts: posts);
    } else if (currentState is PostsLoading) {
      yield PostsLoaded.first(posts: posts);
    }
  }

  /// Handles the event emitted when the posts must be synced uploading
  /// all the changes stored locally to the chain
  Stream<PostsListState> _mapSyncPostsListEventToState() async* {
    final currentState = state;
    if (currentState is PostsLoaded) {
      // Show the snackbar
      yield currentState.copyWith(syncingPosts: true);

      // Wait for the sync
      _syncPostsUseCase.sync().catchError((error) {
        print("Sync error: $error");
        add(SyncPostsCompleted());
      }).then((syncedPosts) {
        add(SyncPostsCompleted());
      });
    }
  }

  /// Handles the event that tells the bloc the synchronization has completed
  Stream<PostsListState> _mapSyncPostsCompletedEventToState() async* {
    // Once the sync has been completed, hide the bar and load the new posts
    final currentState = state;
    if (currentState is PostsLoaded) {
      yield currentState.copyWith(syncingPosts: false);
    }
  }

  /// Handles the event that tells the Bloc that a transaction has
  /// been successful.
  void _handleTxSuccessfulEvent(TxSuccessful event) async {
    final status = PostStatus(
      value: PostStatusValue.TX_SUCCESSFULL,
      data: event.txHash,
    );
    await _updatePostsStatusUseCase.update(event.txHash, status);
  }

  /// Handles the event that tells the Bloc that a transaction has not
  /// been successful.
  void _handleTxFailedEvent(TxFailed event) async {
    final status = PostStatus(
      value: PostStatusValue.ERRORED,
      data: event.error,
    );
    await _updatePostsStatusUseCase.update(event.txHash, status);
  }

  @override
  Future<void> close() {
    _eventsSubscription?.cancel();
    _postsSubscription?.cancel();
    _txSubscription?.cancel();
    _syncTimer?.cancel();
    return super.close();
  }
}