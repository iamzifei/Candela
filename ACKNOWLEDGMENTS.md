# Acknowledgments

Candela stands on other people's work. This file records what came from where.

## Crisp

Candela is a fork of [Crisp](https://github.com/didriksg/Crisp) by
[Didrik Galteland](https://github.com/didriksg), released under the MIT License.

Crisp is the direct source of Candela's entire display-control layer: the
private-API bridging header (`CGVirtualDisplay`, `CGSConfigureDisplayMode`,
`SLSConfigureDisplayEnabled`, `IOAVService`), the DDC pipeline, HiDPI mode
enumeration, the brightness pipeline, arrangement, presets, and virtual
displays. That work represents years of reverse engineering against undocumented
macOS behaviour, and Candela did not redo it.

Candela differs from Crisp in scope, not in that foundation: it targets macOS 26
only (dropping every backwards-compatibility path), adopts the native Liquid
Glass APIs throughout its interface, and ships its own identity and icon.

**If you want the mature, broadly compatible app, use Crisp.** It supports
macOS 14 and up, it is actively maintained, and it is free.

Crisp's MIT license terms are reproduced in this repository's [LICENSE](LICENSE),
alongside Candela's.

## FreeDisplay

Crisp itself began as a fork of [FreeDisplay](https://github.com/huberdf/FreeDisplay)
by huberdf. FreeDisplay's README declares it released under the MIT License
(its repository ships no LICENSE file). Portions of Candela ultimately derived
from FreeDisplay remain available under those terms, reproduced here:

```
MIT License

Copyright (c) huberdf and FreeDisplay contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Upstream contributors

These contributions landed in Crisp before the fork and are present in Candela:

- [@caicaiks](https://github.com/caicaiks) ([#4](https://github.com/didriksg/Crisp/pull/4), [#13](https://github.com/didriksg/Crisp/pull/13))
- [@shaw-baobao](https://github.com/shaw-baobao) ([#11](https://github.com/didriksg/Crisp/pull/11), [#24](https://github.com/didriksg/Crisp/pull/24))
- [@YuriNachos](https://github.com/YuriNachos) ([#27](https://github.com/didriksg/Crisp/pull/27), [#35](https://github.com/didriksg/Crisp/pull/35), [#36](https://github.com/didriksg/Crisp/pull/36))

Simplified Chinese (简体中文) localization contributed to Crisp by
[@xiangfeidexiaohuo](https://github.com/xiangfeidexiaohuo).
