/// 预置支出/收入分类的 seed 元数据与渲染回退。
///
/// `defaultCategorySeeds` 既是首启 seed 数据源(由 FinanceRepository 落库),
/// 也为 `categoryForId` 提供渲染回退。
///
/// 🟠 待办(P0-5):分类单一真相 —— 渲染应改为从 DB `expenseCategories` 取,
/// `categoryForId` 作为 DB 缺失时的兜底;届时此处的渲染职责收敛。
class CategoryMeta {
  final String id;
  final String icon;
  final String name;
  final bool isIncome;
  const CategoryMeta(this.id, this.icon, this.name, {this.isIncome = false});
}

/// 首启 seed:与旧 finance_providers 的 `_defaultCategorySeeds` 一致。
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

/// 按 id 取分类元数据;DB 无此分类时用 id 兜底(渲染回退)。
CategoryMeta categoryForId(String id) {
  return defaultCategorySeeds.firstWhere(
    (c) => c.id == id,
    orElse: () => CategoryMeta(id, '📦', id),
  );
}
