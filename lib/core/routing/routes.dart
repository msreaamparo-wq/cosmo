abstract final class CosmosRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const gallery = '/gallery';
  static const planets = '/planets';
  static const createPlanet = '/planets/new';
  static String planet(String id) => '/planets/$id';
  static String editPlanet(String id) => '/planets/$id/edit';
  static const favorites = '/favorites';
  static String viewer(String id) => '/viewer/$id';
  static const timeline = '/timeline';
  static const slideshow = '/slideshow';
  static const discover = '/discover';
  static const frames = '/frames';
  static const constellation = '/constellation';
  static const achievements = '/achievements';
  static const settings = '/settings';
  static const parentAuth = '/parent-auth';
}
