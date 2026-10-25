# Японский двор — источники

Геометрия тории, святилища, решётчатых дверей, фонарей, бамбука, камней и водоёма создана кодом проекта в `scripts/japan/japanese_props.gd`. Это пробная стилизация окружения, без сторонних программных компонентов.

- Камень: **Rock 01**, Rob Tuytel / Poly Haven, https://polyhaven.com/a/rock_01 . Карты цвета, нормалей и шероховатости JPG 1K. CC0 1.0: https://polyhaven.com/license . Загружены только три JPG, без архивов и исполняемых файлов.
- Дерево, штукатурка и кровля переиспользуют карты из `resources/textures/gate_street/`; источники и лицензии перечислены в `resources/models/gate_street/SOURCES.md`.
- Трава для островков: существующий материал `resources/textures/ground/sparse_grass_diff.jpg`; исходник Poly Haven, https://polyhaven.com/a/sparse_grass , CC0.
- Герой и противники используют прежние модели проекта, без замены головы и костюмов.

- Подлесок: Fern 02, Rico Cilliers / Rob Tuytel, Poly Haven, https://polyhaven.com/a/fern_02 , CC0. glTF и карты 1K, включая отдельную маску листьев. Загружены только геометрия и изображения.
- Крупные хвойные деревья переиспользуют Fir Sapling Medium из `resources/models/gate_street/fir/`, CC0; источник указан рядом.
- Черепицы, деревянные соединения, фонари, верёвка и неровные валуны создаются кодом `shrine_detail.gd` / `japanese_props.gd`.

- Листья и ветви клёна — собственная геометрия проекта; использует общий материал старого дерева.
