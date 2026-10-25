# Usage: python3 editors/vscode/gen_grammar.py editors/vscode/extended-min/syntaxes/xmin.tmLanguage.json
# Generates the VS Code TextMate grammar for Extended Min. Scopes match the
# Sublime Text syntax (editors/sublime-text/ExtendedMin/ExtendedMin.sublime-syntax).
import json, re, sys
ID = r'[A-Za-z_][A-Za-z0-9_]*'
TY = r'(?:char|int|long)'
BI = r'(?:print|serial|output|append|pop|empty|len|sizeof)'
X = '.xmin'
def s(name): return name + X
def caps(*names): return {str(i+1): {'name': s(n)} for i, n in enumerate(names) if n}

repo = {
  'comments': {'match': r'(#).*$', 'name': s('comment.line.number-sign'),
               'captures': caps('punctuation.definition.comment')},
  'use-import': {'match': r'^\s*(use)\b', 'captures': caps('keyword.control.import')},
  'def': {
    'begin': r'\b(def)\s+(' + ID + r')\s*(\()',
    'beginCaptures': caps('keyword.declaration.function', 'entity.name.function',
                          'punctuation.section.parameters.begin'),
    'end': r'(\))(?:\s*(:))?',
    'endCaptures': caps('punctuation.section.parameters.end', 'punctuation.section.function.begin'),
    'contentName': s('meta.function.parameters'),
    'patterns': [
      {'match': r'\b' + TY + r'\b', 'name': s('support.type')},
      {'match': r'&', 'name': s('storage.modifier.reference')},
      {'match': r',', 'name': s('punctuation.separator.parameters')},
      {'match': ID, 'name': s('variable.parameter')},
      {'include': '#comments'}]},
  'block-statements': {'patterns': [
    {'begin': r'\b(if)\b', 'beginCaptures': caps('keyword.control.conditional.if'),
     'end': r'(:)(?!=)|(?=#)|$', 'endCaptures': caps('punctuation.section.block.conditional'),
     'patterns': [{'include': '#expressions'}]},
    {'begin': r'\b(elif)\b', 'beginCaptures': caps('keyword.control.conditional.elseif'),
     'end': r'(:)(?!=)|(?=#)|$', 'endCaptures': caps('punctuation.section.block.conditional'),
     'patterns': [{'include': '#expressions'}]},
    {'match': r'\b(else)\b(?:\s*(:))?',
     'captures': caps('keyword.control.conditional.else', 'punctuation.section.block.conditional')},
    {'begin': r'\b(while)\b', 'beginCaptures': caps('keyword.control.loop.while'),
     'end': r'(:)(?!=)|(?=#)|$', 'endCaptures': caps('punctuation.section.block.loop'),
     'patterns': [{'include': '#expressions'}]}]},
  'const-decl': {'match': r'\b(' + TY + r')\s+(' + ID + r')\s*(:=)',
                 'captures': caps('storage.type', 'variable.other.constant',
                                  'keyword.operator.assignment.constant')},
  'declaration': {'match': r'\b(' + TY + r')\s+(' + ID + r')\b(?!\s*\()',
                  'captures': caps('storage.type', 'variable.other.declaration')},
  'initializer-separator': {'match': r',', 'name': s('punctuation.separator.sequence')},
  'expressions': {'patterns': [{'include': '#' + k} for k in
    ('comments', 'strings', 'blob', 'numbers', 'keywords', 'calls', 'types',
     'groups', 'item-access', 'operators')] + [
    {'match': r';', 'name': s('punctuation.terminator.statement')},
    {'match': ID, 'name': s('variable.other')}]},
  'keywords': {'patterns': [
    {'match': r'\bbreak\b', 'name': s('keyword.control.flow.break')},
    {'match': r'\breturn\b', 'name': s('keyword.control.flow.return')},
    {'match': r'\bcall\b', 'name': s('keyword.control.flow.call')},
    {'match': r'\b(?:not|and|or|xor)\b', 'name': s('keyword.operator.logical')}]},
  'calls': {'patterns': [
    {'begin': r'\b(' + head + r')\s*(\()',
     'beginCaptures': caps(scope, 'punctuation.section.arguments.begin'),
     'end': r'\)', 'endCaptures': {'0': {'name': s('punctuation.section.arguments.end')}},
     'contentName': s('meta.function-call.arguments'),
     'patterns': [{'match': r',', 'name': s('punctuation.separator.arguments')},
                  {'include': '#expressions'}]}
    for head, scope in ((TY, 'support.type'), (BI, 'support.function.builtin'),
                        (ID, 'variable.function'))]},
  'types': {'match': r'\b' + TY + r'\b', 'name': s('storage.type')},
  'groups': {'begin': r'\(', 'beginCaptures': {'0': {'name': s('punctuation.section.group.begin')}},
             'end': r'\)', 'endCaptures': {'0': {'name': s('punctuation.section.group.end')}},
             'name': s('meta.group'), 'patterns': [{'include': '#expressions'}]},
  'item-access': {'begin': r'\[', 'beginCaptures': {'0': {'name': s('punctuation.section.brackets.begin')}},
                  'end': r'\]', 'endCaptures': {'0': {'name': s('punctuation.section.brackets.end')}},
                  'name': s('meta.item-access'),
                  'patterns': [{'match': r'\|', 'name': s('punctuation.separator.slice')},
                               {'include': '#expressions'}]},
  'numbers': {'patterns': [
    {'match': r'\b(0[xX])[0-9A-Fa-f]+\b', 'name': s('constant.numeric.integer.hexadecimal'),
     'captures': caps('punctuation.definition.numeric.base')},
    {'match': r'\b[0-9]+\b', 'name': s('constant.numeric.integer.decimal')}]},
  'strings': {'begin': r'"', 'beginCaptures': {'0': {'name': s('punctuation.definition.string.begin')}},
              'end': r'(")|$', 'endCaptures': caps('punctuation.definition.string.end'),
              'name': s('string.quoted.double'),
              'patterns': [{'match': r'\\.', 'name': s('constant.character.escape')}]},
  'blob': {'begin': r'(\$)(\()',
           'beginCaptures': caps('storage.type.string', 'punctuation.section.blob.begin'),
           'end': r'\)', 'endCaptures': {'0': {'name': s('punctuation.section.blob.end')}},
           'name': s('meta.blob'),
           'patterns': [{'include': '#comments'},
                        {'match': r'\b(0[xX])[0-9A-Fa-f]{1,2}\b', 'name': s('constant.numeric.integer.hexadecimal'),
                         'captures': caps('punctuation.definition.numeric.base')},
                        {'match': r',', 'name': s('punctuation.separator.blob')},
                        {'match': r'\S', 'name': s('invalid.illegal.blob-value')}]},
  'operators': {'patterns': [
    {'match': r':=', 'name': s('keyword.operator.assignment.constant')},
    {'match': r'\+=|-=', 'name': s('keyword.operator.assignment.augmented')},
    {'match': r'<<|>>', 'name': s('keyword.operator.bitwise')},
    {'match': r'==|!=|<=|>=|<|>', 'name': s('keyword.operator.comparison')},
    {'match': r'=', 'name': s('keyword.operator.assignment')},
    {'match': r'[-+*/]', 'name': s('keyword.operator.arithmetic')},
    {'match': r'\b_\b', 'name': s('keyword.operator.concatenation')},
    {'match': r'@', 'name': s('keyword.operator.address')},
    {'match': r'&', 'name': s('keyword.operator.reference')},
    {'match': r':', 'name': s('punctuation.section.block')}]},
}
g = {'$schema': 'https://raw.githubusercontent.com/martinring/tmlanguage/master/tmlanguage.json',
     'name': 'Extended Min', 'scopeName': 'source.xmin', 'fileTypes': ['xmin'],
     'comment': 'Generated to match editors/sublime-text/ExtendedMin/ExtendedMin.sublime-syntax. '
                'Keywords mirror the interpreter tokenizer keyword table; scope names follow the Python grammar.',
     'patterns': [{'include': '#' + k} for k in
       ('comments', 'use-import', 'def', 'block-statements', 'const-decl', 'declaration',
        'initializer-separator', 'expressions')],
     'repository': repo}
# sanity: every regex compiles and every include resolves
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ('match', 'begin', 'end'): re.compile(v)
            if k == 'include': assert v[1:] in repo, v
            walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(g)
json.dump(g, open(sys.argv[1], 'w'), indent=2); open(sys.argv[1], 'a').write('\n')
print('ok', len(repo), 'repository rules')
