require! \gulp
require! \gulp-livescript

gulp.task \build, ->
    gulp.src <[./src/*.ls]>
        .pipe gulp-livescript!
        .pipe gulp.dest \./src

gulp.task \watch, ->
    gulp.watch <[./src/*.ls]>, <[build]>

gulp.task \default, <[watch build]>