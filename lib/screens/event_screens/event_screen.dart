import 'dart:async';

import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'create_event_screen.dart';
import 'event_model.dart';
import 'event_service.dart';
import 'event_map_screen.dart';
import '../../utils/role_utils.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({Key? key}) : super(key: key);

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;
  final TextEditingController _searchController = TextEditingController();
  late final EventService _eventService;
  late TabController _tabController;
  List<String> _userRoles = [];
  bool _isLoadingRole = true;
  StreamSubscription<QuerySnapshot>? _userRoleSubscription;

  // Add these for real-time event updates
  StreamSubscription<List<Event1Model>>? _allEventsSubscription;
  StreamSubscription<List<Event1Model>>? _myEventsSubscription;
  List<Event1Model> _allEvents = [];
  List<Event1Model> _myEvents = [];
  bool _isLoadingEvents = true;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String? get _userEmail => FirebaseAuth.instance.currentUser?.email;

  @override
  void initState() {
    super.initState();
    _eventService = EventService();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index;
          _searchController.clear();
        });
      }
    });
    _listenToUserRole();
    _listenToEvents();
  }

  void _listenToUserRole() {
    if (_userEmail == null) {
      setState(() {
        _isLoadingRole = false;
      });
      return;
    }

    // Cancel any existing subscription
    _userRoleSubscription?.cancel();

    // Set loading state
    setState(() {
      _isLoadingRole = true;
    });

    try {
      // Create a listener that updates in real-time
      _userRoleSubscription = FirebaseFirestore.instance
          .collection('usersData')
          .where('email', isEqualTo: _userEmail)
          .limit(1)
          .snapshots()
          .listen(
            (QuerySnapshot userSnapshot) {
              if (userSnapshot.docs.isNotEmpty) {
                var userData =
                    userSnapshot.docs.first.data() as Map<String, dynamic>;
                setState(() {
                  _userRoles = parseRolesFromUserData(userData);
                  _isLoadingRole = false;
                });
                print('User roles updated: $_userRoles');
              } else {
                setState(() {
                  _userRoles = [];
                  _isLoadingRole = false;
                });
              }
            },
            onError: (error) {
              print('Error listening to user role from Firestore: $error');
              setState(() {
                _isLoadingRole = false;
              });
            },
          );
    } catch (e) {
      print('Error setting up user role listener: $e');
      setState(() {
        _isLoadingRole = false;
      });
    }
  }

  void _listenToEvents() {
    // Cancel existing subscriptions
    _allEventsSubscription?.cancel();
    _myEventsSubscription?.cancel();

    setState(() {
      _isLoadingEvents = true;
    });

    // Listen to all events
    try {
      _allEventsSubscription = _eventService.getAllEvents().listen(
        (events) {
          if (mounted) {
            setState(() {
              _allEvents = events;
              _isLoadingEvents = false;
            });
          }
        },
        onError: (error) {
          print('Error listening to all events: $error');
          if (mounted) {
            setState(() {
              _isLoadingEvents = false;
            });
          }
        },
      );

      // Listen to my events
      _myEventsSubscription = _eventService
          .getMyEvents(_uid)
          .listen(
            (events) {
              if (mounted) {
                setState(() {
                  _myEvents = events;
                });
              }
            },
            onError: (error) {
              print('Error listening to my events: $error');
            },
          );
    } catch (e) {
      print('Error setting up event listeners: $e');
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _userRoleSubscription?.cancel();
    _allEventsSubscription?.cancel();
    _myEventsSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _canCreateEvent {
    return rolesCanManageVenueAndEvents(_userRoles);
  }

  List<Event1Model> _getFilteredEvents(bool isMyEvents) {
    final events = isMyEvents ? _myEvents : _allEvents;
    if (_searchController.text.isEmpty) return events;

    return events
        .where(
          (e) => e.eventName.toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: const Text(
          'Events',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: darkAppBarBackground,
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: appGradient,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'All Events'),
                Tab(text: 'My Events'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoadingRole || _isLoadingEvents
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBB86FC)),
            )
          : Column(
              children: [
                // Search bar
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: darkBackgroundPrimary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: recntsColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                        size: 20,
                      ),
                      hintText: 'Search events...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Color(0xFF8696A0),
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [_buildEventsList(false), _buildEventsList(true)],
                  ),
                ),
              ],
            ),
      // Floating action button for My Events tab
      floatingActionButton: _currentTab == 1
          ? _isLoadingRole
                ? null
                : Container(
                    decoration: BoxDecoration(
                      gradient: appGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: recntsColor.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      onPressed: () async {
                        if (!_canCreateEvent) {
                          AppToast.show(
                            'Only Organizers and Venues can create events',
                            isError: true,
                          );
                          return;
                        }
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateEventScreen(),
                          ),
                        );
                        // No need to refresh manually, listener will handle it
                      },
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  )
          : null,
    );
  }

  Widget _buildEventsList(bool isMyEvents) {
    final filteredEvents = _getFilteredEvents(isMyEvents);

    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMyEvents ? Icons.event_busy : Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isMyEvents ? 'No Events Available' : 'No matching events',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isMyEvents
                  ? _canCreateEvent
                        ? 'Create your first event to get started'
                        : 'Check back later for events from artists'
                  : 'Try a different search term',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: EventCard(
          event: filteredEvents[index],
          currentUserId: _uid,
          currentUserRoles: _userRoles,
          onDelete: (eventId) async {
            try {
              await _eventService.deleteEvent(eventId);
              Fluttertoast.showToast(msg: "Event deleted successfully");
              // No need to manually refresh, listener will handle it
            } catch (e) {
              Fluttertoast.showToast(msg: "Failed to delete event: $e");
            }
          },
          onEdit: (event) async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateEventScreen(event: event),
              ),
            );
            // No need to manually refresh, listener will handle it
          },
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final Event1Model event;
  final String currentUserId;
  final List<String> currentUserRoles;
  final Function(String) onDelete;
  final Function(Event1Model) onEdit;

  const EventCard({
    Key? key,
    required this.event,
    required this.currentUserId,
    this.currentUserRoles = const [],
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

  bool get _isOwner => event.ownerId == currentUserId;

  bool get _canEditOrDelete {
    return _isOwner && rolesCanManageVenueAndEvents(currentUserRoles);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Navigate to map screen if coordinates are available
            if (event.latitude != null && event.longitude != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventMapScreen(
                    latitude: event.latitude!,
                    longitude: event.longitude!,
                    eventName: event.eventName,
                    eventAddress: event.address,
                  ),
                ),
              );
            } else {
              // Show message if no coordinates available
              AppToast.show(
                'Location coordinates not available for this event',
                isError: true,
              );
            }
          },
          splashColor: const Color(0xFFBB86FC).withOpacity(0.3),
          highlightColor: const Color(0xFFBB86FC).withOpacity(0.1),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accent.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 140,
                              height: 110,
                              child: Image.network(
                                event.imageUrl,
                                width: 140,
                                height: 110,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    width: 140,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF2A2A2A),
                                          const Color(0xFF1F1F1F),
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFBB86FC),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  width: 130,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accent.withOpacity(0.3),
                                        const Color(
                                          0xFF6200EE,
                                        ).withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.event,
                                    color: Color(0xFFBB86FC),
                                    size: 50,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent.withOpacity(0.2),
                                const Color(0xFF6200EE).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                event.latitude != null &&
                                        event.longitude != null
                                    ? Icons.map
                                    : Icons.location_off,
                                size: 16,
                                color: accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                event.latitude != null &&
                                        event.longitude != null
                                    ? 'Tap to view location'
                                    : 'Location not set',
                                style: TextStyle(
                                  color: accent.withOpacity(0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  event.eventName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isOwner)
                                _canEditOrDelete
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => onEdit(event),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    backgroundColor:
                                                        const Color(0xFF1F1F1F),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    title: const Text(
                                                      'Delete Event',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    content: const Text(
                                                      'Are you sure you want to delete this event?',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              context,
                                                            ),
                                                        child: const Text(
                                                          'Cancel',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.white70,
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          onDelete(event.id);
                                                        },
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(
                                                    0.2,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.visibility,
                                              size: 14,
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'View Only',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _infoText(Icons.person, 'Artist', event.artistName),
                          const SizedBox(height: 6),
                          _infoText(Icons.location_on, 'Place', event.place),
                          const SizedBox(height: 6),
                          _infoText(
                            Icons.access_time,
                            'Time',
                            '${event.startTime} – ${event.endTime}',
                          ),
                          const SizedBox(height: 6),
                          _infoText(Icons.calendar_today, 'Date', event.date),
                          const SizedBox(height: 12),

                          // Show role badge if user is owner but cannot edit (no organizer/venue role)
                          if (_isOwner &&
                              !rolesCanManageVenueAndEvents(currentUserRoles))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: Colors.orange.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Organizers & Venues only - Cannot edit',
                                    style: TextStyle(
                                      color: Colors.orange.withOpacity(0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoText(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
