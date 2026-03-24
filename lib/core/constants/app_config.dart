class AppConfig {
  static const defaultBaseUrl = 'https://erp.montexsoft.com';
  static const salesUploadBaseUrl = 'https://test.montexsoft.com';

  static const oauthTokenPath = '/oauth/token';
  static const connectorUserPath = '/connector/api/user';
  static const connectorContactsPath = '/connector/api/contactapi';
  static const connectorTaxonomyPath = '/connector/api/taxonomy';
  static const connectorBusinessLocationsPath =
      '/connector/api/business-location';
  static const connectorSellPath = '/connector/api/sell';
  static const updatePasswordPath = '/api/update-password';
  static const productEndpointCandidates = <String>[
    '/connector/api/product',
    '/connector/api/products',
  ];
}
