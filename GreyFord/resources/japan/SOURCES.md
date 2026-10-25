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

## Детализация после дождя

- Rock Moss Set 01: Kless Gyzen, https://polyhaven.com/a/rock_moss_set_01 — шесть сканированных валунов; исходные glTF/BIN и нормализованная производная копия в `detail_assets/rock_moss_set_01/`.
- Wooden Bucket 01: James Ray Cock, https://polyhaven.com/a/wooden_bucket_01 — деревянная утварь с картами цвета, нормалей и ARM 1K.
- Gravelly Sand: https://polyhaven.com/a/gravelly_sand — карты гравия 1K.
- Все перечисленные ассеты — CC0, https://polyhaven.com/license . Файлы проверены по размерам и MD5 манифеста; загружены только модели и изображения, без программ и архивов.
- Кабуто, воротник и пояс Аки, полые чаши, ковш, лавка, опавшие листья и пламя — собственная геометрия и шейдеры проекта. Модель и голова Мары сохраняются.
