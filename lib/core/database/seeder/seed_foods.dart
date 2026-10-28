/// Alimento de la semilla offline. Valores por 100 g, redondeados de USDA
/// FoodData Central (SR Legacy / Foundation); los platos preparados son
/// estimaciones de recetas típicas.
class SeedFood {
  const SeedFood(
    this.name,
    this.servingLabel,
    this.servingGrams,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.sodiumMg,
    this.potassiumMg,
    this.magnesiumMg,
    this.calciumMg,
    this.ironMg,
    this.zincMg, [
    this.vitaminCMg = 0,
    this.vitaminDUg = 0,
    this.vitaminB12Ug = 0,
  ]);

  final String name;
  final String servingLabel;
  final double servingGrams;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodiumMg;
  final double potassiumMg;
  final double magnesiumMg;
  final double calciumMg;
  final double ironMg;
  final double zincMg;
  final double vitaminCMg;
  final double vitaminDUg;
  final double vitaminB12Ug;
}

/// Orden de los valores: nombre, porción, gramos de la porción, kcal,
/// proteína, carbohidratos, grasa, fibra, azúcar (g); sodio, potasio, magnesio,
/// calcio, hierro, zinc (mg); vitamina C (mg), D (µg), B12 (µg).
const List<SeedFood> seedFoods = <SeedFood>[
  // ---------- Carnes, aves y pescados ----------
  SeedFood('Pechuga de pavo asada', '100 g', 100, 135, 30, 0, 1, 0, 0, 99, 293, 32, 11, 0.7, 1.5, 0, 0.1, 0.4),
  SeedFood('Carne molida de res magra (cocida)', '100 g', 100, 217, 26.1, 0, 11.8, 0, 0, 72, 360, 22, 12, 2.8, 6.3, 0, 0.1, 2.6),
  SeedFood('Carne molida de res 80/20 (cocida)', '100 g', 100, 254, 25.9, 0, 16.2, 0, 0, 75, 318, 21, 18, 2.6, 6.2, 0, 0.1, 2.6),
  SeedFood('Lomo de cerdo asado', '100 g', 100, 206, 27, 0, 10, 0, 0, 52, 361, 26, 18, 0.9, 2.4, 0, 0.6, 0.7),
  SeedFood('Chuleta de cerdo a la plancha', '1 chuleta', 120, 231, 26, 0, 13.5, 0, 0, 62, 352, 25, 22, 0.8, 2.3, 0, 0.5, 0.6),
  SeedFood('Tocino frito', '2 tiras', 16, 541, 37, 1.4, 42, 0, 0, 1717, 565, 34, 11, 1.4, 3.5, 0, 0.4, 1.2),
  SeedFood('Jamón de cerdo en rebanadas', '2 rebanadas', 40, 145, 21, 1.5, 5.5, 0, 1, 1200, 287, 22, 8, 0.9, 2, 0, 0.5, 0.6),
  SeedFood('Salchicha tipo Frankfurt', '1 unidad', 45, 290, 10.5, 4.2, 26, 0, 1.2, 1090, 166, 11, 11, 1.1, 1.7, 0, 0.5, 1.1),
  SeedFood('Chorizo', '1 unidad', 60, 455, 24, 1.9, 38, 0, 0, 1235, 398, 18, 8, 1.6, 3.4, 0, 0, 2),
  SeedFood('Hígado de res cocido', '100 g', 100, 175, 27, 5.2, 4.7, 0, 0, 79, 351, 22, 6, 6.5, 5.3, 1.9, 1.2, 70.6),
  SeedFood('Pollo asado con piel', '1 presa', 120, 239, 27.3, 0, 13.6, 0, 0, 82, 223, 23, 15, 1.3, 1.9, 0, 0.1, 0.3),
  SeedFood('Alitas de pollo horneadas', '4 alitas', 120, 290, 27, 0, 19.5, 0, 0, 82, 184, 19, 15, 1.3, 1.8, 0, 0.1, 0.3),
  SeedFood('Tilapia a la plancha', '1 filete', 120, 128, 26, 0, 2.7, 0, 0, 56, 380, 34, 14, 0.7, 0.4, 0, 3.7, 1.9),
  SeedFood('Pescado blanco cocido (merluza, bacalao)', '1 filete', 120, 105, 23, 0, 0.9, 0, 0, 78, 244, 42, 14, 0.5, 0.6, 1, 1.2, 1),
  SeedFood('Sardinas en aceite (escurridas)', '1 lata', 90, 208, 24.6, 0, 11.5, 0, 0, 307, 397, 39, 382, 2.9, 1.3, 0, 4.8, 8.9),
  SeedFood('Camarones cocidos', '100 g', 100, 99, 24, 0.2, 0.3, 0, 0, 224, 259, 39, 70, 0.5, 1.6, 0, 0, 1.5),
  SeedFood('Atún en aceite (escurrido)', '1 lata', 120, 198, 29, 0, 8.2, 0, 0, 354, 207, 31, 13, 1.4, 0.9, 0, 6.7, 2.2),
  SeedFood('Salmón ahumado', '50 g', 50, 117, 18.3, 0, 4.3, 0, 0, 784, 175, 18, 11, 0.9, 0.3, 0, 17, 3.3),

  // ---------- Lácteos ----------
  SeedFood('Leche entera', '1 vaso (240 ml)', 244, 61, 3.2, 4.8, 3.3, 0, 4.8, 43, 132, 10, 113, 0, 0.4, 0, 1.3, 0.5),
  SeedFood('Leche descremada', '1 vaso (240 ml)', 245, 34, 3.4, 5, 0.1, 0, 5, 42, 156, 11, 122, 0, 0.4, 0, 1.2, 0.5),
  SeedFood('Leche deslactosada semidescremada', '1 vaso (240 ml)', 245, 46, 3.3, 4.8, 1.5, 0, 4.8, 44, 150, 11, 120, 0, 0.4, 0, 1.2, 0.5),
  SeedFood('Bebida de almendras sin azúcar', '1 vaso (240 ml)', 240, 15, 0.6, 0.6, 1.2, 0.2, 0, 72, 67, 7, 184, 0.3, 0.1, 0, 1),
  SeedFood('Yogur natural entero', '1 vaso (170 g)', 170, 61, 3.5, 4.7, 3.3, 0, 4.7, 46, 155, 12, 121, 0.1, 0.6, 0.5, 0.1, 0.4),
  SeedFood('Kéfir natural', '1 vaso (240 ml)', 240, 41, 3.8, 4.5, 1, 0, 4.6, 40, 164, 12, 130, 0, 0.5, 0, 1.1, 0.3),
  SeedFood('Queso mozzarella', '30 g', 30, 300, 22, 2.2, 22, 0, 1, 627, 76, 20, 505, 0.4, 2.9, 0, 0.4, 2.3),
  SeedFood('Queso cheddar', '30 g', 30, 403, 23, 1.3, 33, 0, 0.5, 653, 98, 28, 710, 0.1, 3.6, 0, 0.6, 1.1),
  SeedFood('Queso cottage', '1/2 taza', 113, 98, 11.1, 3.4, 4.3, 0, 2.7, 364, 104, 8, 83, 0.1, 0.4, 0, 0.1, 0.4),
  SeedFood('Queso crema', '1 cucharada', 15, 342, 6, 4.1, 34, 0, 3.2, 321, 138, 9, 98, 0.1, 0.5, 0, 0.6, 0.2),
  SeedFood('Queso parmesano rallado', '1 cucharada', 5, 392, 35.8, 3.2, 25.8, 0, 0.8, 1376, 125, 38, 1184, 0.8, 2.8, 0, 0.5, 1.2),
  SeedFood('Mantequilla con sal', '1 cucharadita', 5, 717, 0.9, 0.1, 81, 0, 0.1, 643, 24, 2, 24, 0, 0.1, 0, 1.5, 0.2),
  SeedFood('Crema de leche', '1 cucharada', 15, 340, 2.8, 2.7, 36, 0, 2.7, 27, 95, 7, 66, 0.1, 0.2, 0.6, 1.6, 0.2),

  // ---------- Frutas ----------
  SeedFood('Naranja', '1 mediana', 130, 47, 0.9, 11.8, 0.1, 2.4, 9.4, 0, 181, 10, 40, 0.1, 0.1, 53.2),
  SeedFood('Mandarina', '1 mediana', 75, 53, 0.8, 13.3, 0.3, 1.8, 10.6, 2, 166, 12, 37, 0.2, 0.1, 26.7),
  SeedFood('Fresas', '1 taza', 150, 32, 0.7, 7.7, 0.3, 2, 4.9, 1, 153, 13, 16, 0.4, 0.1, 58.8),
  SeedFood('Mango', '1 taza en trozos', 165, 60, 0.8, 15, 0.4, 1.6, 13.7, 1, 168, 10, 11, 0.2, 0.1, 36.4),
  SeedFood('Papaya', '1 taza en trozos', 145, 43, 0.5, 10.8, 0.3, 1.7, 7.8, 8, 182, 21, 20, 0.3, 0.1, 60.9),
  SeedFood('Piña', '1 taza en trozos', 165, 50, 0.5, 13.1, 0.1, 1.4, 9.9, 1, 109, 12, 13, 0.3, 0.1, 47.8),
  SeedFood('Sandía', '1 tajada', 280, 30, 0.6, 7.6, 0.2, 0.4, 6.2, 1, 112, 10, 7, 0.2, 0.1, 8.1),
  SeedFood('Melón', '1 taza en trozos', 160, 34, 0.8, 8.2, 0.2, 0.9, 7.9, 16, 267, 12, 9, 0.2, 0.2, 36.7),
  SeedFood('Uvas', '1 taza', 150, 69, 0.7, 18.1, 0.2, 0.9, 15.5, 2, 191, 7, 10, 0.4, 0.1, 3.2),
  SeedFood('Pera', '1 mediana', 178, 57, 0.4, 15.2, 0.1, 3.1, 9.8, 1, 116, 7, 9, 0.2, 0.1, 4.3),
  SeedFood('Durazno / melocotón', '1 mediano', 150, 39, 0.9, 9.5, 0.3, 1.5, 8.4, 0, 190, 9, 6, 0.3, 0.2, 6.6),
  SeedFood('Kiwi', '1 unidad', 75, 61, 1.1, 14.7, 0.5, 3, 9, 3, 312, 17, 34, 0.3, 0.1, 92.7),
  SeedFood('Arándanos', '1 taza', 148, 57, 0.7, 14.5, 0.3, 2.4, 10, 1, 77, 6, 6, 0.3, 0.2, 9.7),
  SeedFood('Moras', '1 taza', 144, 43, 1.4, 9.6, 0.5, 5.3, 4.9, 1, 162, 20, 29, 0.6, 0.5, 21),
  SeedFood('Guayaba', '1 unidad', 55, 68, 2.6, 14.3, 1, 5.4, 8.9, 2, 417, 22, 18, 0.3, 0.2, 228.3),
  SeedFood('Maracuyá (pulpa)', '1 unidad', 50, 97, 2.2, 23.4, 0.7, 10.4, 11.2, 28, 348, 29, 12, 1.6, 0.1, 30),
  SeedFood('Limón (jugo)', '1 cucharada', 15, 22, 0.4, 6.9, 0.2, 0.3, 2.5, 1, 103, 6, 6, 0.1, 0.1, 38.7),
  SeedFood('Plátano maduro frito (tajadas)', '1/2 plátano', 100, 236, 1.5, 38, 9.2, 2.3, 18, 4, 482, 32, 4, 0.6, 0.2, 10),
  SeedFood('Plátano verde cocido', '1/2 plátano', 120, 116, 0.8, 31.2, 0.2, 2.3, 14, 5, 465, 32, 2, 0.6, 0.1, 10.9),
  SeedFood('Patacón (plátano verde frito)', '2 patacones', 80, 309, 1.5, 50, 11.8, 3.5, 3, 4, 482, 32, 4, 0.6, 0.2, 10),
  SeedFood('Coco rallado', '2 cucharadas', 20, 354, 3.3, 15.2, 33.5, 9, 6.2, 20, 356, 32, 14, 2.4, 1.1, 3.3),
  SeedFood('Dátiles', '3 unidades', 24, 282, 2.5, 75, 0.4, 8, 63, 2, 656, 43, 39, 1, 0.3, 0.4),
  SeedFood('Uvas pasas', '1 puñado', 30, 299, 3.1, 79, 0.5, 3.7, 59, 11, 749, 32, 50, 1.9, 0.2, 2.3),

  // ---------- Verduras ----------
  SeedFood('Tomate', '1 mediano', 120, 18, 0.9, 3.9, 0.2, 1.2, 2.6, 5, 237, 11, 10, 0.3, 0.2, 13.7),
  SeedFood('Lechuga', '1 taza', 50, 17, 1.2, 3.3, 0.3, 2.1, 1.2, 8, 247, 14, 33, 1, 0.2, 4),
  SeedFood('Zanahoria cruda', '1 mediana', 60, 41, 0.9, 9.6, 0.2, 2.8, 4.7, 69, 320, 12, 33, 0.3, 0.2, 5.9),
  SeedFood('Cebolla', '1/2 unidad', 50, 40, 1.1, 9.3, 0.1, 1.7, 4.2, 4, 146, 10, 23, 0.2, 0.2, 7.4),
  SeedFood('Pimentón rojo', '1/2 unidad', 75, 31, 1, 6, 0.3, 2.1, 4.2, 4, 211, 12, 7, 0.4, 0.3, 127.7),
  SeedFood('Pepino', '1/2 unidad', 100, 15, 0.7, 3.6, 0.1, 0.5, 1.7, 2, 147, 13, 16, 0.3, 0.2, 2.8),
  SeedFood('Calabacín', '1 taza', 120, 17, 1.2, 3.1, 0.3, 1, 2.5, 8, 261, 18, 16, 0.4, 0.3, 17.9),
  SeedFood('Champiñones', '1 taza', 70, 22, 3.1, 3.3, 0.3, 1, 2, 5, 318, 9, 3, 0.5, 0.5, 2.1, 0.2),
  SeedFood('Coliflor cocida', '1 taza', 124, 23, 1.8, 4.1, 0.5, 2.3, 2.1, 15, 142, 9, 16, 0.3, 0.2, 44.3),
  SeedFood('Habichuelas / ejotes cocidos', '1 taza', 125, 35, 1.9, 7.9, 0.3, 3.2, 3.6, 1, 146, 18, 44, 0.7, 0.3, 9.7),
  SeedFood('Remolacha cocida', '1/2 taza', 85, 44, 1.7, 10, 0.2, 2, 8, 77, 305, 23, 16, 0.8, 0.4, 3.6),
  SeedFood('Ahuyama / calabaza cocida', '1 taza', 245, 20, 0.7, 4.9, 0.1, 1.1, 2.1, 1, 230, 9, 15, 0.6, 0.2, 4.7),
  SeedFood('Kale / col rizada', '1 taza', 40, 35, 2.9, 4.4, 1.5, 4.1, 1, 53, 348, 33, 254, 1.6, 0.4, 93.4),
  SeedFood('Repollo', '1 taza', 70, 25, 1.3, 5.8, 0.1, 2.5, 3.2, 18, 170, 12, 40, 0.5, 0.2, 36.6),
  SeedFood('Mazorca de maíz cocida', '1 mazorca', 100, 96, 3.4, 21, 1.5, 2.4, 4.5, 1, 218, 26, 3, 0.5, 0.6, 5.5),
  SeedFood('Espárragos cocidos', '6 unidades', 90, 22, 2.4, 4.1, 0.2, 2, 1.3, 14, 224, 14, 23, 0.9, 0.6, 7.7),
  SeedFood('Berenjena cocida', '1 taza', 100, 35, 0.8, 8.7, 0.2, 2.5, 3.2, 1, 123, 11, 6, 0.3, 0.1, 1.3),
  SeedFood('Arvejas cocidas', '1/2 taza', 80, 84, 5.4, 15.6, 0.2, 5.5, 5.9, 3, 271, 39, 27, 1.5, 1.2, 14.2),
  SeedFood('Ajo', '1 diente', 5, 149, 6.4, 33, 0.5, 2.1, 1, 17, 401, 25, 181, 1.7, 1.2, 31.2),

  // ---------- Tubérculos, cereales y panes ----------
  SeedFood('Batata / camote al horno', '1 mediana', 150, 90, 2, 20.7, 0.2, 3.3, 6.5, 36, 475, 27, 38, 0.7, 0.3, 19.6),
  SeedFood('Yuca cocida', '1 trozo', 150, 112, 1.4, 27, 0.3, 1.4, 1.7, 8, 271, 21, 16, 0.3, 0.3, 20),
  SeedFood('Papas a la francesa', 'porción mediana', 117, 312, 3.4, 41, 15, 3.8, 0.3, 210, 579, 35, 18, 0.8, 0.5, 4.7),
  SeedFood('Puré de papa', '1 taza', 210, 106, 1.9, 15.8, 4.2, 1.5, 1.5, 300, 284, 18, 25, 0.3, 0.3, 6),
  SeedFood('Arroz integral cocido', '1 taza', 195, 123, 2.7, 25.6, 1, 1.6, 0.2, 4, 86, 39, 3, 0.6, 0.7),
  SeedFood('Quinoa cocida', '1 taza', 185, 120, 4.4, 21.3, 1.9, 2.8, 0.9, 7, 172, 64, 17, 1.5, 1.1),
  SeedFood('Pasta cocida', '1 taza', 140, 158, 5.8, 30.9, 0.9, 1.8, 0.6, 1, 44, 18, 7, 1.3, 0.5),
  SeedFood('Pasta integral cocida', '1 taza', 140, 149, 6, 30, 1.7, 3.9, 0.8, 4, 96, 53, 13, 1.7, 1.1),
  SeedFood('Cuscús cocido', '1 taza', 157, 112, 3.8, 23.2, 0.2, 1.4, 0.1, 5, 58, 8, 8, 0.4, 0.3),
  SeedFood('Pan blanco de molde', '1 rebanada', 28, 265, 9, 49, 3.2, 2.7, 5, 491, 115, 25, 151, 3.6, 0.7),
  SeedFood('Pan integral de molde', '1 rebanada', 32, 252, 12.4, 43, 3.5, 6, 4.4, 450, 250, 76, 161, 2.5, 1.8),
  SeedFood('Pan francés / baguette', '1 trozo', 60, 274, 10.8, 52, 2.4, 2.2, 5, 600, 117, 27, 52, 3.6, 0.9),
  SeedFood('Croissant', '1 unidad', 57, 406, 8.2, 45.8, 21, 2.6, 11.3, 467, 118, 16, 37, 2, 0.8),
  SeedFood('Tortilla de maíz', '1 unidad', 26, 218, 5.7, 44.6, 2.9, 6.3, 0.9, 45, 186, 72, 81, 1.2, 0.9),
  SeedFood('Tortilla de trigo', '1 unidad', 45, 306, 8, 50, 8, 3.5, 2.8, 736, 125, 23, 128, 3.6, 0.6),
  SeedFood('Galletas de soda', '4 unidades', 12, 421, 9.5, 74, 8.8, 2.7, 1.3, 950, 165, 27, 22, 5.4, 0.8),
  SeedFood('Galleta de arroz inflado', '1 unidad', 9, 387, 8.2, 81.5, 2.8, 4.2, 0.9, 29, 290, 131, 11, 1.5, 3),
  SeedFood('Granola', '1/2 taza', 45, 471, 10.5, 64, 20, 7, 24, 26, 380, 95, 76, 3.4, 2.3),
  SeedFood('Cereal de hojuelas de maíz', '1 taza', 30, 357, 7.5, 84, 0.4, 3.3, 9.5, 729, 102, 22, 5, 18, 0.4),
  SeedFood('Avena cocida en agua', '1 taza', 234, 71, 2.5, 12, 1.5, 1.7, 0.3, 4, 70, 27, 9, 0.9, 1),

  // ---------- Legumbres y soya ----------
  SeedFood('Frijoles rojos cocidos', '1 taza', 170, 127, 8.7, 22.8, 0.5, 7.4, 0.3, 2, 405, 45, 28, 2.9, 1.1),
  SeedFood('Frijoles negros cocidos', '1 taza', 170, 132, 8.9, 23.7, 0.5, 8.7, 0.3, 1, 355, 70, 27, 2.1, 1.1),
  SeedFood('Garbanzos cocidos', '1 taza', 160, 164, 8.9, 27.4, 2.6, 7.6, 4.8, 7, 291, 48, 49, 2.9, 1.5),
  SeedFood('Hummus', '2 cucharadas', 30, 166, 7.9, 14.3, 9.6, 6, 0.3, 379, 228, 71, 38, 2.4, 1.8),
  SeedFood('Tofu firme', '100 g', 100, 144, 17.3, 2.8, 8.7, 2.3, 0.6, 14, 237, 58, 683, 2.7, 1.6),
  SeedFood('Edamame', '1 taza', 155, 121, 11.9, 8.9, 5.2, 5.2, 2.2, 6, 436, 64, 63, 2.3, 1.4, 6.1),
  SeedFood('Mantequilla de maní', '2 cucharadas', 32, 588, 25, 20, 50, 6, 9.2, 459, 649, 154, 43, 1.7, 2.8),

  // ---------- Frutos secos y semillas ----------
  SeedFood('Maní tostado sin sal', '1 puñado', 30, 585, 23.7, 21.5, 49.7, 8, 4.2, 6, 658, 176, 54, 2.3, 3.3),
  SeedFood('Nueces', '1 puñado', 30, 654, 15.2, 13.7, 65.2, 6.7, 2.6, 2, 441, 158, 98, 2.9, 3.1),
  SeedFood('Marañones / anacardos', '1 puñado', 30, 553, 18.2, 30.2, 43.9, 3.3, 5.9, 12, 660, 292, 37, 6.7, 5.8),
  SeedFood('Pistachos', '1 puñado', 30, 560, 20.2, 27.2, 45.3, 10.6, 7.7, 1, 1025, 121, 105, 3.9, 2.2),
  SeedFood('Semillas de chía', '1 cucharada', 12, 486, 16.5, 42.1, 30.7, 34.4, 0, 16, 407, 335, 631, 7.7, 4.6),
  SeedFood('Linaza molida', '1 cucharada', 10, 534, 18.3, 28.9, 42.2, 27.3, 1.6, 30, 813, 392, 255, 5.7, 4.3),
  SeedFood('Semillas de girasol', '1 puñado', 30, 584, 20.8, 20, 51.5, 8.6, 2.6, 9, 645, 325, 78, 5.3, 5),
  SeedFood('Semillas de calabaza', '1 puñado', 30, 559, 30.2, 10.7, 49, 6, 1.4, 7, 809, 592, 46, 8.8, 7.8),

  // ---------- Bebidas ----------
  SeedFood('Jugo de naranja natural', '1 vaso (240 ml)', 248, 45, 0.7, 10.4, 0.2, 0.2, 8.4, 1, 200, 11, 11, 0.2, 0.1, 50),
  SeedFood('Agua de coco', '1 vaso (240 ml)', 240, 19, 0.7, 3.7, 0.2, 1.1, 2.6, 105, 250, 25, 24, 0.3, 0.1, 2.4),
  SeedFood('Café con leche', '1 taza (240 ml)', 240, 47, 2.6, 4.3, 1.9, 0, 4, 40, 140, 10, 90, 0.1, 0.3, 0, 0.9, 0.3),
  SeedFood('Té verde sin azúcar', '1 taza (240 ml)', 240, 1, 0.2, 0, 0, 0, 0, 1, 8, 1, 0, 0, 0),
  SeedFood('Bebida deportiva', '1 botella (500 ml)', 500, 26, 0, 6.4, 0, 0, 5.6, 41, 12, 0, 0, 0, 0),
  SeedFood('Gaseosa de cola', '1 lata (355 ml)', 368, 42, 0, 10.6, 0, 0, 10.6, 4, 2, 0, 2, 0, 0),
  SeedFood('Gaseosa de cola sin azúcar', '1 lata (355 ml)', 355, 1, 0.1, 0.1, 0, 0, 0, 4, 8, 1, 2, 0, 0),
  SeedFood('Cerveza', '1 lata (330 ml)', 330, 43, 0.5, 3.6, 0, 0, 0, 4, 27, 6, 4, 0, 0),
  SeedFood('Vino tinto', '1 copa (150 ml)', 150, 85, 0.1, 2.6, 0, 0, 0.6, 4, 127, 12, 8, 0.5, 0.1),

  // ---------- Grasas, salsas y dulces ----------
  SeedFood('Aceite vegetal (girasol, canola)', '1 cucharada', 14, 884, 0, 0, 100, 0, 0, 0, 0, 0, 0, 0, 0),
  SeedFood('Aceite de coco', '1 cucharada', 14, 862, 0, 0, 99, 0, 0, 0, 0, 0, 1, 0, 0),
  SeedFood('Mayonesa', '1 cucharada', 14, 680, 1, 0.6, 75, 0, 0.6, 635, 20, 1, 8, 0.2, 0.1),
  SeedFood('Salsa de tomate (kétchup)', '1 cucharada', 17, 101, 1, 27, 0.1, 0.3, 22.8, 907, 281, 13, 15, 0.4, 0.2, 4.1),
  SeedFood('Salsa de soya', '1 cucharada', 16, 53, 8.1, 4.9, 0.6, 0.8, 0.4, 5493, 435, 43, 33, 1.5, 0.4),
  SeedFood('Sal de mesa', '1 pizca', 1, 0, 0, 0, 0, 0, 0, 38758, 8, 1, 24, 0.3, 0.1),
  SeedFood('Azúcar blanca', '1 cucharadita', 4, 387, 0, 100, 0, 0, 100, 1, 2, 0, 1, 0, 0),
  SeedFood('Panela', '1 trozo', 20, 375, 0.4, 95, 0.1, 0, 90, 30, 300, 70, 85, 2, 0.5),
  SeedFood('Miel de abejas', '1 cucharada', 21, 304, 0.3, 82.4, 0, 0.2, 82.1, 4, 52, 2, 6, 0.4, 0.2, 0.5),
  SeedFood('Mermelada', '1 cucharada', 20, 278, 0.4, 68.9, 0.1, 1.1, 48.5, 32, 77, 4, 20, 0.5, 0.1, 8.8),
  SeedFood('Chocolate oscuro 70 %', '2 cuadros', 20, 598, 7.8, 45.9, 42.6, 10.9, 24, 20, 715, 228, 73, 11.9, 3.3),
  SeedFood('Chocolate con leche', '1 barra', 40, 535, 7.7, 59.4, 29.7, 3.4, 51.5, 79, 372, 63, 189, 2.4, 2.3),
  SeedFood('Helado de vainilla', '1 bola', 66, 207, 3.5, 23.6, 11, 0.7, 21.2, 80, 199, 11, 128, 0.1, 0.7, 0.6, 0.2, 0.4),

  // ---------- Platos y suplementos comunes ----------
  SeedFood('Huevos pericos (con tomate y cebolla)', '1 porción', 150, 135, 9, 3, 9.5, 0.6, 1.8, 180, 180, 11, 50, 1.3, 1, 5, 1.5, 0.8),
  SeedFood('Arroz con pollo', '1 plato', 250, 155, 9, 19, 4.5, 0.8, 0.8, 380, 150, 18, 15, 0.9, 0.9),
  SeedFood('Sopa de verduras', '1 plato', 250, 28, 1.2, 4.6, 0.6, 1, 1.5, 280, 160, 8, 15, 0.4, 0.1, 2),
  SeedFood('Ensalada mixta sin aderezo', '1 plato', 150, 17, 1.2, 3.5, 0.2, 1.6, 2, 20, 220, 12, 25, 0.6, 0.2, 15),
  SeedFood('Empanada de carne frita', '1 unidad', 90, 320, 10, 30, 18, 2, 1.5, 450, 180, 20, 30, 1.8, 1.5),
  SeedFood('Pizza de queso', '1 porción', 107, 266, 11.4, 33.3, 9.7, 2.3, 3.6, 598, 172, 24, 188, 2.4, 1.3),
  SeedFood('Hamburguesa sencilla', '1 unidad', 110, 254, 12.9, 28.7, 9.6, 1.5, 6, 488, 216, 22, 103, 2.5, 2),
  SeedFood('Rollo de sushi de salmón', '8 piezas', 200, 146, 5.8, 28, 2, 0.8, 4, 350, 120, 14, 10, 0.4, 0.5),
  SeedFood('Proteína whey en polvo', '1 medida (30 g)', 30, 380, 78, 8, 5, 0, 5, 300, 500, 100, 400, 1, 2),
  SeedFood('Barra de proteína', '1 barra', 60, 350, 30, 40, 11, 8, 5, 300, 250, 60, 200, 3, 2),
];
