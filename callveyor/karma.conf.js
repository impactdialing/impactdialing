// Karma configuration
// http://karma-runner.github.io/0.10/config/configuration-file.html

module.exports = function(config) {
  config.set({
    // base path, that will be used to resolve files and exclude
    basePath: '',

    preprocessors: {
      'app/scripts/**/*.coffee': 'coffee',
      // 'test/spec/**/*.coffee': 'coffee'
      // 'scripts/**/*.tpl.html': ['ng-html2js']
    },

    // ngHtml2JsPreprocessor: {
    //   // strip this from the file path
    //   stripPrefix: '/callveyor',
    //   // prepend this to the
    //   prependPrefix: '/scripts',
    //
    //   // or define a custom transform function
    //   // cacheIdFromPath: function(filepath) {
    //   //   return cacheId;
    //   // },
    //
    //   // setting this option will create only a single module that contains templates
    //   // from all the files, so you can load them all with module('foo')
    //   moduleName: 'templates'
    // },

    // testing framework to use (jasmine/mocha/qunit/...)
    frameworks: ['jasmine'],

    // list of files / patterns to load in the browser
    files: [
      'app/bower_components/angular/angular.js',
      'app/bower_components/angular-mocks/angular-mocks.js',
      'app/bower_components/angular-bootstrap/ui-bootstrap-tpls.js',
      'app/bower_components/angular-ui-router/release/angular-ui-router.js',
      'app/bower_components/angular-pusher/angular-pusher.js',
      'app/bower_components/angular-spinner/angular-spinner.js',
      'app/bower_components/spin.js/spin.js',
      {pattern: 'app/scripts/**/*.tpl.html', served: true, included: false},
      'app/scripts/config.js',
      'app/scripts/*.coffee',
      'app/scripts/dialer/*.coffee',
      'app/scripts/**/*.coffee',
      // 'test/spec/**/*.coffee',
      'app/scripts/survey-templates.js',
    ],

    // list of files / patterns to exclude
    exclude: [],

    // web server port
    port: 8080,

    // possible values: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
    logLevel: config.LOG_DEBUG,

    autoWatch: true,


    // Start these browsers, currently available:
    // - Chrome
    // - ChromeCanary
    // - Firefox
    // - Opera
    // - Safari (only Mac)
    // - PhantomJS
    // - IE (only Windows)
    browsers: ['Chrome', 'Firefox', 'Safari'],
    // browsers: ['Firefox'],


    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: false
  });
};
