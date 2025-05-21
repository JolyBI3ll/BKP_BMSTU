/* eslint-env node */
const gulp = require('gulp');
const $ = require('gulp-load-plugins')();
const merge = require('merge-stream');

const paths = {
  jade:    'partials/*.jade',
  coffee:  'coffee/*.coffee',
  images:  'images/**/*',
  dist:    'dist/'
};

gulp.task('copy-config', () =>
  gulp.src('drawio.json').pipe(gulp.dest(paths.dist))
);

gulp.task('copy-images', () =>
  gulp.src(paths.images).pipe(gulp.dest(paths.dist + 'images'))
);

gulp.task('compile', () => {
  const jade = gulp.src(paths.jade)
    .pipe($.jade({ pretty: true }))
    .pipe($.angularTemplatecache({
      transformUrl: url => '/plugins/drawio' + url
    }));

  const coffee = gulp.src(paths.coffee)
    .pipe($.coffee());

  return merge(jade, coffee)
    .pipe($.concat('drawio.js'))
    .pipe($.uglify({ mangle: false, annotations: false }))
    .pipe(gulp.dest(paths.dist));
});

gulp.task('watch', () =>
  gulp.watch([paths.jade, paths.coffee, paths.images],
             gulp.series('copy-images','compile'))
);

gulp.task('default',
  gulp.series('copy-config','copy-images','compile','watch')
);

gulp.task('build',
  gulp.series('copy-config','copy-images','compile')
);