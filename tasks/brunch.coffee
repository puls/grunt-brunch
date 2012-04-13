module.exports = (grunt) ->
  task = grunt.task
  file = grunt.file
  utils = grunt.utils
  log = grunt.log
  verbose = grunt.verbose
  fail = grunt.fail
  option = grunt.option
  config = grunt.config
  template = grunt.template
  path = require 'path'
  fs = require 'fs'
  mkdirp = require 'mkdirp'
  
  getPlugins = () ->
    plugins = []
    includePath = file.findup('.', 'node_modules')
    modules = file.expand "#{includePath}/*-brunch"
    for modulePath in modules
      name = (modulePath.match /\/(.+-brunch)\/$/)[1]
      plugin = require name
      if (plugin.prototype.brunchPlugin)
        plugins.push new plugin
          rootPath: '.'
    plugins

  grunt.registerTask "compile", "Compile code resources.", ->
    grunt.helper("compile")

  grunt.registerHelper "compile", ->
    buildPath = config ['compile', 'buildPath']
    outputFiles = {}
    plugins = getPlugins()
    log.write "compiling to #{buildPath}\n"
    asyncCallback = task.current.async()
    compiles = 1
    
    done = (result) ->
      for outputPath, fileHandle of outputFiles
        fs.closeSync fileHandle
      outputFiles = {}
      asyncCallback(result)
    
    for type, options of config ['compile', 'files']
      outputs = options.joinTo

      if typeof outputs == 'string'
        outputPath = outputs
        outputs = {}
        outputs[outputPath] = //
      for outputPath, regexOrFunction of outputs
        if regexOrFunction instanceof RegExp
          ((regex) ->
            outputs[outputPath] = (filename) -> filename.match regex
          )(regexOrFunction)

      compileFile = (filename) ->
        for outputPath, filter of outputs
          unless outputFiles[outputPath]?
            fullOutputPath = path.join(buildPath, outputPath)
            mkdirp.sync path.dirname fullOutputPath
            outputFiles[outputPath] = fs.openSync fullOutputPath, 'w'

          if filter filename
            for plugin in plugins
              if "#{plugin.type}s" == type
                if ".#{plugin.extension}" == path.extname filename
                  ((outputPath) ->
                    compiles += 1
                    plugin.compile fs.readFileSync(filename, 'utf8'), path.resolve(filename), (error, output) ->
                      compiles -= 1
                      fs.writeSync outputFiles[outputPath], output
                      done(true) if compiles is 0
                  )(outputPath)

      file.recurse 'vendor', compileFile
      file.recurse 'app', compileFile

    compiles -= 1
