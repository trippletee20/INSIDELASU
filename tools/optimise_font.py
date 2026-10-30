#!/usr/bin/env python3
"""Freeze unused variable axes at their original default; keep every glyph."""
import argparse
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
p=argparse.ArgumentParser()
p.add_argument('source')
p.add_argument('output')
a=p.parse_args()
f=TTFont(a.source)
if 'fvar' not in f: raise SystemExit('Input must be the original variable font')
cmap=f.getBestCmap().copy()
metrics=f['hmtx'].metrics.copy()
axes={axis.axisTag:axis.defaultValue for axis in f['fvar'].axes}
static=instantiateVariableFont(f,axes,inplace=False)
assert static.getBestCmap()==cmap
assert static['hmtx'].metrics==metrics
assert static.getGlyphOrder()==f.getGlyphOrder()
static.save(a.output)
print('Preserved',len(cmap),'Unicode mappings and',len(f.getGlyphOrder()),'glyphs; axes',axes)
