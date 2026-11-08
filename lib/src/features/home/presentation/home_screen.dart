import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    final name = (metadata?['display_name'] as String?)?.trim();
    final greeting = name == null || name.isEmpty ? 'أهلاً بك' : 'أهلاً، $name';
    final now = DateTime.now();
    final weekday = const [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ][now.weekday - 1];
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 3) {
            context.go('/study-space');
          } else if (i == 4) {
            context.go('/insights');
          } else if (i > 0) {
            context.go('/academics');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'موادي',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'المخطط',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            label: 'الدراسة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'حسابي',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: StudyBridgeColors.lilacWash,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: StudyBridgeColors.purple,
                            ),
                          ),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip: 'تسجيل الخروج',
                            onPressed: () async {
                              await ref.read(authRepositoryProvider).signOut();
                              if (context.mounted) context.go('/login');
                            },
                            icon: const Icon(Icons.logout_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '$weekday، ${now.day}/${now.month}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        greeting,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      Text(
                        'خطوة هادئة اليوم تكفي لتصنع فرقاً.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      _FocusCard(onPressed: () => context.go('/focus')),
                      const SizedBox(height: 20),
                      Text(
                        'مساحتك اليوم',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      const _EmptySection(
                        icon: Icons.menu_book_outlined,
                        title: 'موادك تبدأ من هنا',
                        subtitle:
                            'أضف موادك ومحاضراتك لتظهر خطتك الدراسية هنا.',
                      ),
                      const SizedBox(height: 14),
                      const _EmptySection(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'لا توجد مهام بعد',
                        subtitle: 'تظهر المهام القادمة في قسم موادي.',
                      ),
                      const SizedBox(height: 20),
                      const _PartnerCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF352546), Color(0xFF17131F)],
      ),
      boxShadow: [
        BoxShadow(
          color: StudyBridgeColors.purple.withValues(alpha: .14),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      border: Border.all(color: StudyBridgeColors.gold.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'وقتٌ لك ولأحلامك',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'ابدأ جلسة تركيز قصيرة',
                style: TextStyle(color: StudyBridgeColors.muted, fontSize: 15),
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(Icons.timer_outlined, size: 19),
                label: Text('ابدأ الآن'),
                style: ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(Colors.white),
                  side: WidgetStatePropertyAll(
                    BorderSide(color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Icon(Icons.nightlight_round, size: 66, color: StudyBridgeColors.gold),
      ],
    ),
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: StudyBridgeColors.background,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: StudyBridgeColors.purple),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: StudyBridgeColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: StudyBridgeColors.border),
    ),
    child: const Row(
      children: [
        Icon(Icons.auto_awesome_rounded, color: StudyBridgeColors.purple),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'المكان هنا لك ولمن تدعوه. ستظهر حالة شريك الدراسة بعد إعداد المساحة المشتركة.',
            style: TextStyle(color: StudyBridgeColors.ink, height: 1.55),
          ),
        ),
      ],
    ),
  );
}
