part of "../home_screen.dart";

Widget _drawer({required BuildContext context, required authRepository}) {
  final User user = authRepository.currentSession?.user;

  // Function to fetch organization name from Supabase
  Future<String?> getOrganizationName(String? organizationId) async {
    if (organizationId == null) return null;
    final supabase =
        Supabase.instance.client; // Assuming Supabase is initialized globally
    try {
      final response = await supabase
          .from('organizations') // Replace 'organizations' with your table name
          .select(
              'name') // Assuming 'name' is the column with the organization name
          .eq('id', organizationId) // Assuming 'id' is the primary key
          .single();

      return response['name'] as String?;
    } catch (e) {
      print('Error fetching organization name: $e');
      return null;
    }
  }

  // Function to fetch app metadata
  Future<PackageInfo> getAppMetadata() async {
    return await PackageInfo.fromPlatform();
  }

  return Drawer(
      shape: const Border(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color.fromARGB(255, 55, 78, 99)
                        : Theme.of(context).primaryColor,
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: user.userMetadata?['picture'] != null
                                  ? Image.network(
                                      user.userMetadata?['picture'],
                                      scale: 1.2,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        return loadingProgress == null
                                            ? child
                                            : const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.black,
                                        ),
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withOpacity(0.2),
                                      child: Text(
                                        user.userMetadata?['iss'] != null
                                            ? "${user.userMetadata?['name'][0]}${user.userMetadata?['name'].split(' ')[1][0]}"
                                            : '${user.userMetadata?['first_name'][0]}${user.userMetadata?['last_name'][0]}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                            ),
                            IconButton(
                              icon: Icon(
                                Theme.of(context).brightness == Brightness.dark
                                    ? Icons.nightlight
                                    : Icons.sunny,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? null
                                    : Colors.white,
                              ),
                              iconSize: 30,
                              onPressed: () {},
                            )
                          ],
                        ),
                        Text(
                          user.userMetadata?['iss'] != null
                              ? "${user.userMetadata?['name']}"
                              : '${user.userMetadata?['first_name']} ${user.userMetadata?['last_name']}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .apply(color: Colors.white, fontWeightDelta: 5),
                        ),
                        FutureBuilder<String?>(
                          future: getOrganizationName(
                              user.userMetadata?['organization']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator(
                                color: Colors.white,
                              );
                            } else if (snapshot.hasError) {
                              return Text(
                                'Error loading organization',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .apply(color: Colors.red),
                              );
                            } else {
                              final organizationName = snapshot.data;
                              return Text(
                                organizationName ?? 'No Organization',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .apply(
                                        color: Colors.white54, fontSizeDelta: 2)
                                    .copyWith(
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              );
                            }
                          },
                        ),
                      ]),
                ),
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: const Icon(
                        Icons.apartment,
                      ),
                    ),
                    Text(
                      'Properties',
                      style: Theme.of(context).textTheme.titleLarge!.apply(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeightDelta: 3),
                    ),
                  ],
                ),
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (BuildContext context, HomeState state) {
                    if (state is HomeLoading) {
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: 3,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return const ListTile(
                            title: ShimmerLoading(
                              child: ShimmerContainer(
                                height: 20,
                                width: double.infinity,
                              ),
                            ),
                            subtitle: ShimmerLoading(
                              child: ShimmerContainer(
                                height: 16,
                                width: 100,
                              ),
                            ),
                          );
                        },
                      );
                    } else if (state is HomeLoaded) {
                      if (state.properties.isEmpty) {
                        return const ListTile(
                          title: Text('No properties yet'),
                          subtitle: Text('Add a property to get started'),
                        );
                      }
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: state.properties.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final property = state.properties[index];
                          final isSelected =
                              state.selectedProperty?.id == property.id;
                          return ListTile(
                            title: Text(property.name),
                            subtitle: Text(property.address),
                            selected: isSelected,
                            onTap: () {
                              context
                                  .read<HomeBloc>()
                                  .add(SelectProperty(property));
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    } else if (state is HomeError) {
                      return _ErrorScreen(
                        error: state.error,
                        onRetry: () => context.read<HomeBloc>().add(LoadHome()),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add_home_work),
                  title: const Text('Add Property'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPropertyScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Column(
            children: [
              ExpansionTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Info'),
                children: [
                  FutureBuilder<PackageInfo>(
                    future: getAppMetadata(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData) {
                        final packageInfo = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text('App Name: ${packageInfo.appName}'),
                            Text('Version: ${packageInfo.version}'),
                            Text('Build Number: ${packageInfo.buildNumber}'),
                          ],
                        );
                      } else {
                        return const Text('No app metadata available');
                      }
                    },
                  )
                ],
              ),
              ListTile(
                trailing: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  context.read<AppBloc>().add(const AppSignOutPressed());
                },
              ),
            ],
          )
        ],
      ));
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorScreen({
    Key? key,
    required this.error,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 120,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something Went Wrong',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
