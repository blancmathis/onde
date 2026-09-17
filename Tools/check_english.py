#!/usr/bin/env python3
"""Catch untranslated app-owned copy. Personal imports and historical docs are not localized."""
from pathlib import Path
import re, sys
root = Path(__file__).resolve().parents[1]
problems = []
# Accented French letters and common untranslated UI wording. Source comments,
# stable ASCII identifiers, reference filenames and legacy metadata are excluded.
accented = re.compile(r'[àâäéèêëîïôöùûüçÉÀÈÊ]')
words = re.compile(r'\b(?:La|Le|Les|Aucune|Aucun|Choisissez|Votre|Vos|vous|votre|vos|Une|une|Les|les|Veuillez|Impossible de|Ouvrir|Fermer|Annuler|Rechercher|Enregistrer|Activer|Aucun|aucun|sonores|couches|chronomètre)\b')
for path in (root / 'Sources').rglob('*.swift'):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if line.lstrip().startswith('//'):
            continue
        for literal in re.findall(r'"(?:\\.|[^"\\])*"', line):
            # Exact legacy field prefix, used only to display old import metadata in English.
            if literal == '"Import personnel"':
                continue
            if accented.search(literal) or words.search(literal):
                problems.append(f'{path.relative_to(root)}:{number}: {literal}')
        if 'lang="fr"' in line:
            problems.append(f'{path.relative_to(root)}:{number}: French web-player language')
readme = (root / 'README.md').read_text()
if not readme.startswith('# Onde\n'):
    problems.append('README must have one current English entry point')
if 'CFBundleDevelopmentRegion</key><string>en</string>' not in (root/'Tools/package.sh').read_text():
    problems.append('Packaged development language must be English')
if problems:
    print('\n'.join(problems), file=sys.stderr)
    sys.exit(1)
print('English UI/source-copy checks passed (personal content and historical archive excluded).')
