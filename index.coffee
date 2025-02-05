debug = (args...) -> # console.log args...

class ClassInfo

  constructor: (node) ->
    @className = node.determineName()
    @parent = node.parent?.base.value

class FieldInfo

  constructor: (@classInfo, binding) ->
    @varName = binding.variable.base.value
    @fieldType = binding.value.constructor.name
    @value = binding.value

isSuperCall = (expr) ->
  expr.constructor.name is 'SuperCall' or
    # CoffeeScript <1.10.0 support
    (expr.constructor.name is 'Call') and (expr.isSuper? and expr.isSuper)

module.exports = class EnsureSuper

  rule:
    name: 'ensure_super'
    message: 'This method must call super'
    level: 'warn'
    description: 'Checks that subclasses call super in certain methods.'
    check: {}

  processClass: (classNode, api) ->
    info = new ClassInfo classNode
    return unless info.parent
    check = (api.config[@rule.name]?.check ? @rule.check)
    return unless info.parent of check
    classNode.traverseChildren false, (child) =>
      switch child.constructor.name
        when 'Class' then @processClass child, api
        when 'Assign' then @processAssignment child, api, info
        else debug 'Skipping irrelevant node', child.constructor.name

  processAssignment: (binding, api, classInfo) ->
    field = new FieldInfo classInfo, binding
    switch field.fieldType
      when 'Code' then @processMethod field, api
      else debug 'Skipping non method', field.varName

  processMethod: (field, api) ->
    conf = (api.config[@rule.name]?.check ? @rule.check)
    meths = conf[field.classInfo.parent]
    return unless meths?.length
    if field.varName in meths
      @checkMethod field, api

  checkMethod: (method, api) ->
    unless method.value.body.expressions.some isSuperCall
      @errors.push api.createError
        message: "#{ method.varName } must call super"
        lineNumber: method.value.locationData.first_line + 1
        lineNumberEnd: method.value.locationData.last_line + 1

  lintNode: (node, api) ->
    node.traverseChildren false, (child) =>
      type = child.constructor.name
      switch type
        when 'Class' then @processClass child, api
        else debug 'Skipping irrelevant node', type
    return # Errors are listed in @errors.

  lintAST: (root, api) -> @lintNode root, api
