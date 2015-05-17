gulp = require 'gulp'
coffee = require 'gulp-coffee'
lint = require 'gulp-coffeelint'
jasmine = require 'gulp-jasmine'
istanbul = require 'gulp-coffee-istanbul'

glob = (dir, ext = 'coffee') -> "#{dir}/**/*.#{ext}"
lib = glob('lib')
src = glob('src')
test = glob('test')

gulp.task 'build', ->
  gulp.src([lib, src])
  .pipe(coffee({ bare: true }))
  .pipe(gulp.dest('dist/'))

gulp.task 'lint', ->
  gulp.src(lib)
  .pipe(lint())
  .pipe(lint.reporter())

gulp.task 'test', ['build'], ->
  gulp.src(lib)
  .pipe(istanbul({ includeUntested: true }))
  .pipe(istanbul.hookRequire())
  .on 'finish', ->
    gulp.src(test)
    .pipe(jasmine())
    .pipe(istanbul.writeReports())

gulp.task 'default', ['lint', 'build', 'test']