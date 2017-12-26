'use strict';

var isWin = /^win/.test(process.platform);

const gulp = require('gulp'),
    del = require('del'),
    gulpIf = require('gulp-if'),
    concat = require('gulp-concat'),
    through = require('through2'),
    debug = require('gulp-debug'),
    gulpIgnore = require('gulp-ignore'),
    fs = require("fs"),
    p = require('./package.json');

gulp.task('create-directory',function () {
    return new Promise((resolve, reject) => {
        if (!fs.existsSync("./build/"))
            fs.mkdirSync("build");
        resolve();
    })
} );

let FILE_LISTCLS;
gulp.task('enum-files:cls', function() {
    FILE_LISTCLS = [];
    return gulp.src('./_CLS/**/*.*',{read: false})
        .pipe(gulpIgnore.exclude('*.xml'))
        .pipe(through.obj(function (chunk, enc, cb) {
            if (!chunk.isDirectory()) FILE_LISTCLS.push(chunk.relative);
            cb(null, chunk);
        }));
});

let FILE_LISTDFI;
gulp.task('enum-files:dfi', function() {
    FILE_LISTDFI = [];
    return gulp.src('_DFI/*.*',{read: false})
        .pipe(gulpIgnore.exclude('*.xml'))
        .pipe(through.obj(function (chunk, enc, cb) {
            if (!chunk.isDirectory()) FILE_LISTDFI.push(chunk.relative);
            cb(null, chunk);
        }));
});

gulp.task('create-xml-package:cls', function () {
    return new Promise((resolve, reject)=>{
        if (!FILE_LISTCLS || !Array.isArray(FILE_LISTCLS) || FILE_LISTCLS.length === 0)
            reject(new Error('Please, build project before create package.'));

        let append = '';

        for (let i = 0; i < FILE_LISTCLS.length; i++) {

            console.log('CLS: Adding file:', FILE_LISTCLS[i]);
            let content = fs.readFileSync('./_CLS/' + FILE_LISTCLS[i], 'binary');
            content = new Buffer(content, 'binary').toString('base64');

            let step = 32767;
            let k = step;

            while (k < content.length) {
                content = content.substring(0,k) + '\r\n' + content.substring(k, content.length);
                k += step;
            }

            append +=
                `<XData name="File${i}">
    <Description>${FILE_LISTCLS[i].replace(isWin ? /\\/g : /\//g,".")}</Description>
    <MimeType>text/plain</MimeType>
    <Data><![CDATA[${content}]]></Data>
</XData>`;

        }

        append = '<Class name="DeepSeeAudit.CLSData">' + append + '</Class>';
        fs.writeFileSync('./build/DeepSeeAudit.CLSData.xml', append);

        FILE_LISTCLS.length = 0;
        resolve();
    });
});

gulp.task('create-xml-package:dfi', function () {
    return new Promise((resolve, reject)=>{
        if (!FILE_LISTDFI || !Array.isArray(FILE_LISTDFI) || FILE_LISTDFI.length === 0)
            reject(new Error('Please, build project before create package.'));

        let append = '';

        for (let i = 0; i < FILE_LISTDFI.length; i++) {

            console.log('DFI: Adding file:', FILE_LISTDFI[i]);
            let content = fs.readFileSync('./_DFI/' + FILE_LISTDFI[i], 'binary');
            content = new Buffer(content, 'binary').toString('base64');

            let step = 32767;
            let k = step;

            while (k < content.length) {
                content = content.substring(0,k) + '\r\n' + content.substring(k, content.length);
                k += step;
            }

            append +=

                `<XData name="File${i}">
    <Description>${FILE_LISTDFI[i].replace(/_/g, " ")}</Description>
    <MimeType>text/plain</MimeType>
    <Data><![CDATA[${content}]]></Data>
</XData>`;

        }

        append = '<Class name="DeepSeeAudit.DFIData">' + append + '</Class>';
        fs.writeFileSync('./build/DeepSeeAudit.DFIData.xml', append);

        FILE_LISTDFI.length = 0;
        resolve();
    });
});

gulp.task('concat-installer-files', function () {
    return new Promise((resolve,reject)=>{
        let installer = fs.readFileSync('./Installer.xml','utf8');
        let CLSFiles = fs.readFileSync('./build/DeepSeeAudit.CLSData.xml','utf8');
        let DFIFiles = fs.readFileSync('./build/DeepSeeAudit.DFIData.xml','utf8');

        installer = installer.substring(0,installer.length-11) + CLSFiles + DFIFiles + "</Export>";

        fs.writeFileSync('./build/Installer' + p.version + '.xml', installer);
        resolve();
    });
});

gulp.task('cleanup:before-creating-installer', function () {
    return new Promise((resolve,reject)=>{
        del('build/Installer*.xml');
        resolve();
    });
});

gulp.task('cleanup:after-creating-installer', function () {
    return new Promise((resolve,reject)=>{
        del('build/DeepSeeAudit.*.xml');
        resolve();
    });
});

gulp.task('create-package:cls', gulp.series('enum-files:cls','create-xml-package:cls'));
gulp.task('create-package:dfi', gulp.series('enum-files:dfi','create-xml-package:dfi'));
gulp.task('create-package',gulp.parallel('create-package:cls','create-package:dfi'));
gulp.task('create-install-file', gulp.series('create-directory','cleanup:before-creating-installer', 'create-package', 'concat-installer-files', 'cleanup:after-creating-installer'));
gulp.task('default', gulp.series('create-install-file'));