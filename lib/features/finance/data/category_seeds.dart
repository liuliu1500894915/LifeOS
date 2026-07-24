/// 预置支出/收入分类的 seed 元数据。
///
/// P0-5 起:仅作首启 seed 数据源(由 [FinanceRepository] 落库)。交易列表的
/// 分类名/图标改由 DB join `expenseCategories` 取(单一真相),不再用此处
/// 硬编码做渲染回退。
class CategoryMeta {
  final String id;
  final String icon;
  final String name;
  final bool isIncome;
  const CategoryMeta(this.id, this.icon, this.name, {this.isIncome = false});
}

/// 首启 seed:12 条(9 支出 + 3 收入),与旧 finance_providers 的
/// `_defaultCategorySeeds` 一致。
const List<CategoryMeta> defaultCategorySeeds = [
  CategoryMeta('food', '🍱', '三餐'),
  CategoryMeta('transport', '🚗', '交通'),
  CategoryMeta('entertainment', '🎉', '娱乐'),
  CategoryMeta('drink', '💧', '饮品'),
  CategoryMeta('shopping', '🛒', '购物'),
  CategoryMeta('housing', '🏠', '住房'),
  CategoryMeta('pet', '🐱', '宠物'),
  CategoryMeta('other', '⚙️', '自定义'),
  CategoryMeta('subscription', '🔄', '订阅'),
  CategoryMeta('salary', '💰', '工资', isIncome: true),
  CategoryMeta('bonus', '🎁', '奖金', isIncome: true),
  CategoryMeta('investment', '📈', '投资收益', isIncome: true),
];
