import 'package:flutter/material.dart';

import 'customize_models.dart';
import 'yours_connector_table.dart';

/// Customize 系页面（顶层 /customize 路由 + 设置弹窗里的 Skills/Connectors/
/// Plugins 三个子页）共用的演示数据。没有后端，先用同一份 mock 保证三处
/// 视觉一致，避免各页各写一份导致后续修改漂移。

// ---- Skills ----

List<Map<String, Object>> buildYoursSkills() => [
      {
        'icon': Icons.list_alt,
        'title': 'analyze',
        'source': 'Anthropic',
        'description':
            'Answer data questions — from quick lookups to full analyses. Use when looking up a single metric, investigat...',
        'timeAgo': '12h ago',
      },
      {
        'icon': Icons.build,
        'title': 'build-dashboard',
        'source': 'Anthropic',
        'description':
            'Build an interactive HTML dashboard with charts, filters, and tables. Use when creating an executive overvie...',
        'timeAgo': '12h ago',
      },
      {
        'icon': Icons.palette,
        'title': 'create-viz',
        'source': 'Anthropic',
        'description':
            'Create publication-quality visualizations with Python. Use when turning query results or a DataFrame into a c...',
        'timeAgo': '12h ago',
      },
      {
        'icon': Icons.data_exploration,
        'title': 'data-context-extractor',
        'source': 'Anthropic',
        'description':
            'Generate or improve a company-specific data analysis skill by extracting tribal knowledge from analysts BO...',
        'timeAgo': '12h ago',
      },
      {
        'icon': Icons.bar_chart,
        'title': 'data-visualization',
        'source': 'Anthropic',
        'description':
            'Create effective data visualizations with Python (matplotlib, seaborn, plotly). Use when building charts, choo...',
        'timeAgo': '12h ago',
      },
      {
        'icon': Icons.storage,
        'title': 'explore-data',
        'source': 'Anthropic',
        'description':
            'Profile and explore a dataset to understand its shape, quality, and patterns. Use when encountering a new ta...',
        'timeAgo': '12h ago',
      },
      {
        'icon': Icons.code,
        'title': 'sql-queries',
        'source': 'Anthropic',
        'description':
            'Write correct, performant SQL across all major data warehouse dialects (Snowflake, BigQuery, Databricks, P...',
        'timeAgo': '12h ago',
      },
    ];

List<SkillItem> buildForYouSkills() => [
      SkillItem(
        icon: Icons.list_alt,
        title: 'Operations',
        description:
            'Optimize business operations — vendor management, process documentation, change...',
        source: 'Anthropic',
        installs: '1.3M installs',
      ),
      SkillItem(
        icon: Icons.store,
        title: 'Small Business',
        description:
            'Pre-built small business workflows to help you run and grow your business. Supports a majority of the...',
        source: 'Anthropic',
        installs: '931.4K installs',
      ),
      SkillItem(
        icon: Icons.science,
        title: 'Bio Research',
        description:
            'Connect to preclinical research tools and databases (literature search, genomics analysis, target...',
        source: 'Anthropic',
        installs: '487.3K installs',
      ),
      SkillItem(
        icon: Icons.videocam,
        title: 'Zoom',
        description:
            'Plan, build, and debug Zoom integrations across REST APIs, Meeting SDK, Video SDK, webhooks, bots, an...',
        source: 'Zoom',
        installs: '243.1K installs',
      ),
      SkillItem(
        icon: Icons.bar_chart,
        title: 'Bright Data',
        description:
            'Web scraping, Google search, structured data extraction, and MCP server integration powered by...',
        source: 'Bright Data',
        installs: '237.9K installs',
      ),
      SkillItem(
        icon: Icons.shopping_bag,
        title: 'Product Tracking',
        description:
            'AI agent skills that make SaaS products data-ready for product analytics — from codebase scan to...',
        source: 'Accoll',
        installs: '211K installs',
      ),
      SkillItem(
        icon: Icons.code,
        title: 'Zapier',
        description:
            'Connect 8,000+ apps to your AI workflow. Discover, enable, and execute Zapier actions directly from yo...',
        source: 'Zapier',
        installs: '149.7K installs',
      ),
      SkillItem(
        icon: Icons.table_chart,
        title: 'Airtable',
        description:
            'Airtable is the database and operations layer for your agents — whether running product, marketing, sale...',
        source: 'Airtable',
        installs: '117.3K installs',
      ),
    ];

List<SkillItem> buildNewSkills() => [
      SkillItem(
        icon: Icons.apartment,
        title: 'Wingspan',
        description:
            'Ask Claude about the contractors you pay through Wingspan, what you owe them, and what is holding...',
        source: 'Wingspan Engineering',
        installs: 'added 2 days ago',
        tags: const ['Engineering'],
      ),
      SkillItem(
        icon: Icons.warning,
        title: 'incident.io',
        description:
            'Work with incident.io from Claude: respond to and investigate incidents, check on-call schedules and...',
        source: 'incident.io',
        installs: 'added 2 days ago',
        tags: const ['Engineering', '+1'],
      ),
    ];

/// 「New skills」Show all 的全量列表 —— 参考图里那一屏目录条目。
List<SkillItem> buildAllNewSkills() => [
      SkillItem(
        icon: Icons.gavel,
        title: 'verification-foundation',
        description:
            'Ten jurisdiction-neutral skills for checking legal AI output before it reaches a client or a filing.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Legal', '+2'],
      ),
      SkillItem(
        icon: Icons.trending_up,
        title: 'Revenue Grid',
        description: 'Revenue Grid plugin',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Sales', '+3'],
      ),
      SkillItem(
        icon: Icons.favorite_border,
        title: 'A Good Sign',
        description:
            'Privately explore the Apple Health data you choose to sync, without sending it anywhere.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Health & fitness'],
      ),
      SkillItem(
        icon: Icons.shopping_cart_outlined,
        title: 'WEM Price Compare',
        description:
            'Compare a product\'s price across retailers with WEM — same basket, every store.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Shopping', '+1'],
      ),
      SkillItem(
        icon: Icons.attach_money,
        title: 'TickerLayer',
        description:
            'Latest prices, price history and market hours for crypto, forex and equities.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Personal finance', '+1'],
      ),
      SkillItem(
        icon: Icons.cloud_outlined,
        title: 'Kube by Kuberno',
        description:
            'Search and read entities, officers and appointments from Kube.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Legal', '+2'],
      ),
      SkillItem(
        icon: Icons.code,
        title: 'FAF Skills',
        description:
            'Claude Code skills for persistent project context: create, search, and reuse what you learned.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Engineering', '+2'],
      ),
      SkillItem(
        icon: Icons.article_outlined,
        title: 'Usero',
        description:
            'The direct line from user to engineer. Search your feedback for themes worth acting on.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Product', '+2'],
      ),
      SkillItem(
        icon: Icons.show_chart,
        title: 'Declle',
        description:
            'Declle is an ecommerce customer intelligence platform. Track cohorts and churn in one place.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Sales', '+3'],
      ),
      SkillItem(
        icon: Icons.window_outlined,
        title: 'Komdai',
        description:
            'Design and build user interfaces with the installed Komdai design system.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Design', '+2'],
      ),
      SkillItem(
        icon: Icons.memory,
        title: 'megapowers',
        description:
            'Native-first workflow plugin for Claude Code and Codex: plan, build, review, ship.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Engineering', '+5'],
      ),
    ];

// ---- Plugins ----

List<Map<String, Object>> buildYoursPlugins() => [
      {
        'icon': Icons.dataset,
        'title': 'Data',
        'source': 'Anthropic',
        'description': 'Write SQL, explore datasets, and generate insights faster. Runs visualizations and...',
        'timeAgo': '4d ago',
        'tags': ['Data', '+2'],
      },
    ];

List<SkillItem> buildForYouPlugins() => [
      SkillItem(
        icon: Icons.widgets,
        title: 'Plugin Management',
        description: 'Create, customize, and manage plugins tailored to your organization\'s tools and...',
        source: 'Anthropic',
        installs: '8.0M installs',
      ),
      SkillItem(
        icon: Icons.design_services,
        title: 'Design',
        description: 'Accelerate design workflows — critique, design system management, UX writing,...',
        source: 'Anthropic',
        installs: '3.7M installs',
      ),
      SkillItem(
        icon: Icons.engineering,
        title: 'Engineering',
        description: 'Streamline engineering workflows — standups, code review, architecture...',
        source: 'Anthropic',
        installs: '2M installs',
      ),
      SkillItem(
        icon: Icons.brush,
        title: 'Figma',
        description: 'Figma design platform integration. Access design files, extract component...',
        source: 'Figma',
        installs: '733.9K installs',
      ),
      SkillItem(
        icon: Icons.search,
        title: 'SearchFit SEO',
        description: 'Free AI-powered SEO toolkit — audit websites, plan content strategy, optimi...',
        source: 'SearchFit.io',
        installs: '323.1K installs',
      ),
      SkillItem(
        icon: Icons.terminal,
        title: 'Desktop Commander',
        description: 'MCP server for terminal commands, process management, and file operatic...',
        source: 'Anthropic Directory',
        installs: '283.3K installs',
      ),
    ];

List<SkillItem> buildNewPlugins() => [
      SkillItem(
        icon: Icons.calculate,
        title: 'Gateway Tariff Calculator',
        description: 'US import duty, HTS classification, and trade policy changes, from a live tariff...',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Legal', '+2'],
      ),
      SkillItem(
        icon: Icons.groups,
        title: 'Wiser',
        description: 'Skills that work together in your own voice, on files you own, with experts th...',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Legal', '+2'],
      ),
      SkillItem(
        icon: Icons.public,
        title: 'ViralHunt',
        description: 'Discover trending/viral content across TikTok, Instagram, X, Facebook, Pintere...',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Product', '+2'],
      ),
      SkillItem(
        icon: Icons.wb_sunny,
        title: 'morning',
        description: 'Render the user\'s morning brief as a styled HTML artifact, or let it up as a...',
        source: 'Anthropic',
        installs: 'added 2 days ago',
        tags: const ['Product', '+1'],
      ),
    ];

/// 「New plugins」Show all 的全量列表。前两项与 [buildNewPlugins] 是同一批条目，
/// 后面是目录里其余几项，视觉与截图一致。
List<SkillItem> buildAllNewPlugins() => [
      SkillItem(
        icon: Icons.gavel,
        title: 'verification-foundation',
        description:
            'Ten jurisdiction-neutral skills for checking legal AI output before it reaches a client.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Legal', '+2'],
      ),
      SkillItem(
        icon: Icons.trending_up,
        title: 'Revenue Grid',
        description: 'Revenue Grid plugin',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Sales', '+3'],
      ),
      SkillItem(
        icon: Icons.favorite_border,
        title: 'A Good Sign',
        description:
            'Privately explore the Apple Health data you choose to sync, without sending it anywhere.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Health & fitness'],
      ),
      SkillItem(
        icon: Icons.shopping_cart_outlined,
        title: 'WEM Price Compare',
        description:
            'Compare a product\'s price across retailers with WEM — same basket, every store.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Shopping', '+1'],
      ),
      SkillItem(
        icon: Icons.attach_money,
        title: 'TickerLayer',
        description:
            'Latest prices, price history and market hours for crypto, forex and equities.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Personal finance', '+1'],
      ),
      SkillItem(
        icon: Icons.cloud_outlined,
        title: 'Kube by Kuberno',
        description:
            'Search and read entities, officers and appointments from Kube.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Legal', '+2'],
      ),
      SkillItem(
        icon: Icons.code,
        title: 'FAF Skills',
        description:
            'Claude Code skills for persistent project context: create, search, and reuse what you learned.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Engineering', '+2'],
      ),
      SkillItem(
        icon: Icons.article_outlined,
        title: 'Usero',
        description:
            'The direct line from user to engineer. Search your feedback for themes worth acting on.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Product', '+2'],
      ),
      SkillItem(
        icon: Icons.show_chart,
        title: 'Declle',
        description:
            'Declle is an ecommerce customer intelligence platform. Track cohorts and churn in one place.',
        source: 'Anthropic Directory',
        installs: 'added 2 days ago',
        tags: const ['Sales', '+3'],
      ),
    ];

// ---- Connectors ----

List<ConnectorItem> buildConnectors() => [
      ConnectorItem(
        icon: Icons.folder,
        color: const Color(0xFF4285F4),
        title: 'Google Drive',
        description: 'Search, read, and upload files instantly',
        source: 'Google',
      ),
      ConnectorItem(
        icon: Icons.mail,
        color: const Color(0xFFEA4335),
        title: 'Gmail',
        description: 'Draft replies, summarize threads, & search your inbox',
        source: 'Google',
      ),
      ConnectorItem(
        icon: Icons.calendar_today,
        color: const Color(0xFF4285F4),
        title: 'Google Calendar',
        description: 'Manage your schedule and coordinate meetings effortlessly',
        source: 'Google',
      ),
      ConnectorItem(
        icon: Icons.palette,
        color: const Color(0xFF00C4CC),
        title: 'Canva',
        description: 'Search, create, autofill, and export Canva designs',
        source: 'Canva',
      ),
      ConnectorItem(
        icon: Icons.business,
        color: const Color(0xFFD83B01),
        title: 'Microsoft 365',
        description: 'Access your company\'s SharePoint, OneDrive, Outlook, and Teams directly in Claude',
        source: 'Anthropic',
      ),
      ConnectorItem(
        icon: Icons.description,
        color: Colors.black,
        title: 'Notion',
        description: 'Connect your Notion workspace to search, update, and power workflows across tools',
        source: 'Notion',
      ),
      ConnectorItem(
        icon: Icons.design_services,
        color: const Color(0xFFF24E1E),
        title: 'Figma',
        description: 'Generate diagrams and better code from Figma context',
        source: 'Figma',
      ),
      ConnectorItem(
        icon: Icons.forum,
        color: const Color(0xFF611f69),
        title: 'Slack',
        description: 'Send messages, create canvases, and fetch Slack data',
        source: 'Slack',
      ),
      ConnectorItem(
        icon: Icons.hub,
        color: const Color(0xFF0052CC),
        title: 'Atlassian MCP',
        description: 'Read, search and update Jira, Confluence, Bitbucket, Loom and other Atlassian ap...',
        source: 'Atlassian',
      ),
      ConnectorItem(
        icon: Icons.contact_support,
        color: const Color(0xFFFF7A59),
        title: 'HubSpot',
        description: 'CRM context for every account, insight, and action',
        source: 'HubSpot',
      ),
      ConnectorItem(
        icon: Icons.check_circle_outline,
        color: const Color(0xFFF06A6A),
        title: 'Asana',
        description: 'Connect to Asana to coordinate tasks, projects, and goals',
        source: 'Asana',
      ),
      ConnectorItem(
        icon: Icons.timeline,
        color: const Color(0xFF5E6AD2),
        title: 'Linear',
        description: 'Manage issues, projects & team workflows',
        source: 'Linear',
      ),
    ];

/// 「All connectors」Show all 的全量列表：同一批条目后面接着目录里其余几项。
List<ConnectorItem> buildAllConnectors() => [
      ...buildConnectors(),
      ConnectorItem(
        icon: Icons.calendar_month,
        color: const Color(0xFFEA4335),
        title: 'Calendly',
        description: 'Schedule meetings and share your availability without the back and forth',
        source: 'Calendly',
      ),
      ConnectorItem(
        icon: Icons.receipt_long,
        color: const Color(0xFF635BFF),
        title: 'Stripe',
        description: 'Look up customers, payments, and subscriptions from your Stripe account',
        source: 'Stripe',
      ),
      ConnectorItem(
        icon: Icons.account_tree,
        color: const Color(0xFF181717),
        title: 'GitHub',
        description: 'Search repositories, read issues, and follow pull request activity',
        source: 'GitHub',
      ),
      ConnectorItem(
        icon: Icons.view_kanban,
        color: const Color(0xFF0079BF),
        title: 'Trello',
        description: 'Read boards, move cards, and keep project status up to date',
        source: 'Atlassian',
      ),
      ConnectorItem(
        icon: Icons.assignment,
        color: const Color(0xFF00A1E0),
        title: 'Salesforce',
        description: 'Pull account, opportunity, and pipeline context into Claude',
        source: 'Salesforce',
      ),
      ConnectorItem(
        icon: Icons.drive_file_rename_outline,
        color: const Color(0xFF2D8CFF),
        title: 'Zoom',
        description: 'Plan meetings and pull recaps straight from your Zoom account',
        source: 'Zoom',
      ),
    ];

List<YoursConnectorRow> buildYoursConnectors() => [
      YoursConnectorRow(
        icon: Icons.code,
        name: 'GitHub Integration',
        type: 'Web',
        status: 'Connect',
      ),
    ];
