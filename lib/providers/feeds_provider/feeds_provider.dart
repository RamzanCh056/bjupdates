import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../model/music_track_model.dart';
import 'package:flutter/cupertino.dart';
import '../../model/api_models/feed_models/feed_model.dart';

class FeedProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _feedCacheKey = 'feed_posts_data';
  static const String _feedCacheTimestampKey = 'feed_posts_timestamp';

  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _postsSubscription;

  List<Map<String, dynamic>> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  FeedProvider() {
    _loadCachedPostsOrFetch();
  }

  void setIsLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setErrorMessage(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  /// Load cached posts first, then fetch fresh data
  Future<void> _loadCachedPostsOrFetch({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _loadCachedPosts();
      if (cached != null && cached.isNotEmpty) {
        _posts = cached;
        setIsLoading(false);
        notifyListeners();
        // Refresh in background
        fetchPosts(forceRefresh: true);
        return;
      }
    }
    fetchPosts(forceRefresh: forceRefresh);
  }

  /// Load posts from cache
  Future<List<Map<String, dynamic>>?> _loadCachedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_feedCacheKey);
      if (cached == null) return null;

      final list = jsonDecode(cached) as List;
      return list.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        // Convert timestamp back from milliseconds
        if (map['timestamp'] != null) {
          map['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(
            (map['timestamp'] as num).toInt(),
          );
        }
        return map;
      }).toList();
    } catch (e) {
      log('Error loading cached posts: $e');
      return null;
    }
  }

  /// Save posts to cache
  Future<void> _savePostsToCache(List<Map<String, dynamic>> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert Timestamps to milliseconds for JSON encoding
      final cacheData = posts.map((post) {
        final map = <String, dynamic>{};
        post.forEach((key, value) {
          if (value is Timestamp) {
            map[key] = value.millisecondsSinceEpoch;
          } else {
            map[key] = value;
          }
        });
        return map;
      }).toList();
      await prefs.setString(_feedCacheKey, jsonEncode(cacheData));
      await prefs.setInt(_feedCacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      log('Error saving posts to cache: $e');
    }
  }

  void fetchPosts({bool forceRefresh = false}) {
    setIsLoading(true);
    setErrorMessage(null);

    // Cancel existing subscription if any
    _postsSubscription?.cancel();

    _postsSubscription = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            try {
              _posts = snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'userId': data['userId'],
                  'fileUrl': data['fileUrl'] ?? '',
                  'likes': data['likes'] ?? 0,
                  'views': data['views'] ?? 0,
                  'impressions': data['impressions'] ?? data['views'] ?? 0,
                  'description': data['description'] ?? '',
                  'userImage': data['userImage'] ?? '',
                  'userFirstName': data['userFirstName'] ?? '',
                  'userSecondName': data['userSecondName'] ?? '',
                  'timestamp': data['timestamp'],
                  'type': data['type'] ?? 'image',
                  'music': data['music'],
                  'questionId': data['questionId'],
                  'location': data['location'],
                  'tags': data['tags'],
                };
              }).toList();

              // Save to cache
              _savePostsToCache(_posts);

              // Clear any previous error messages on successful fetch
              setErrorMessage(null);
              setIsLoading(false);
              notifyListeners();
            } catch (e) {
              log("Error parsing posts: $e");
              setErrorMessage(e.toString());
              setIsLoading(false);
              // Try to load from cache on error
              _loadCachedPosts().then((cached) {
                if (cached != null && cached.isNotEmpty) {
                  _posts = cached;
                  setIsLoading(false);
                  notifyListeners();
                }
              });
            }
          },
          onError: (error) {
            setErrorMessage(error.toString());
            setIsLoading(false);
            // Try to load from cache on error
            _loadCachedPosts().then((cached) {
              if (cached != null && cached.isNotEmpty) {
                _posts = cached;
                setIsLoading(false);
                notifyListeners();
              }
            });
          },
        );
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }

  PostWithMusic? safeMusicDataFromMap(Map<String, dynamic>? musicData) {
    try {
      if (musicData == null) return null;
      return PostWithMusic.fromMap(musicData);
    } catch (e) {
      log('Error parsing music data: $e');
      return null;
    }
  }
}

class FeedsProvider extends ChangeNotifier {
  List<FeedModel> feedsList = [];

  updateFeeds(List<FeedModel> feeds) {
    // Sort feeds by creation date, newest first
    feeds.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    feedsList = feeds;
    notifyListeners();
  }
}
