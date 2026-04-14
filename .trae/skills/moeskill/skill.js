const fs = require('fs');
const path = require('path');
const { marked } = require('marked');
const SkillEnhancementSystem = require('./skill-enhancement-system');

class MoeSkill {
  constructor() {
    this.docs = {};
    this.projectStructure = {};
    this.learningData = {};
    this.enhancementSystem = new SkillEnhancementSystem();
    this.initialize();
  }

  async initialize() {
    console.log('Initializing Moe Social Skill...');
    try {
      // 解析docs目录
      await this.parseDocs();
      // 分析项目结构
      this.analyzeProjectStructure();
      // 加载学习数据
      this.loadLearningData();
      // 启动文档和代码变化监控
      this.startMonitoring();
      console.log('Moe Social Skill initialized successfully!');
    } catch (error) {
      console.error('Error initializing Moe Social Skill:', error);
    }
  }

  startMonitoring() {
    console.log('Starting monitoring...');
    // 每5分钟检查一次文档和代码变化
    setInterval(async () => {
      await this.checkDocumentChanges();
      await this.checkCodeChanges();
    }, 5 * 60 * 1000);
  }

  async checkCodeChanges() {
    const projectRoot = path.join(__dirname, '../../..');
    console.log('Checking for code changes...');
    const hasChanges = await this.detectCodeChanges(projectRoot);
    
    if (hasChanges) {
      console.log('Code changes detected, analyzing impact...');
      await this.analyzeCodeChanges();
      console.log('Code change analysis completed');
    }
  }

  async detectCodeChanges(dir) {
    const currentState = this.getCodeState(dir);
    
    // 保存当前状态到学习数据
    if (!this.learningData.codeState) {
      this.learningData.codeState = currentState;
      return false;
    }
    
    const oldState = this.learningData.codeState;
    const hasChanges = JSON.stringify(currentState) !== JSON.stringify(oldState);
    
    if (hasChanges) {
      this.learningData.codeState = currentState;
      this.saveLearningData();
    }
    
    return hasChanges;
  }

  getCodeState(dir, basePath = '', maxDepth = 3, currentDepth = 0) {
    if (currentDepth >= maxDepth) return {};
    
    const state = {};
    try {
      const files = fs.readdirSync(dir);
      
      files.forEach(file => {
        if (file.startsWith('.') || file === 'node_modules' || file === 'build' || file === 'dist') return;
        
        const fullPath = path.join(dir, file);
        const relativePath = path.join(basePath, file);
        
        try {
          const stats = fs.statSync(fullPath);
          if (stats.isDirectory()) {
            state[file] = this.getCodeState(fullPath, relativePath, maxDepth, currentDepth + 1);
          } else if (this.isCodeFile(file)) {
            state[file] = {
              mtime: stats.mtime.toISOString(),
              size: stats.size
            };
          }
        } catch (error) {
          console.error(`Error getting state for ${fullPath}:`, error);
        }
      });
    } catch (error) {
      console.error(`Error reading directory ${dir}:`, error);
    }
    
    return state;
  }

  isCodeFile(file) {
    const codeExtensions = ['.dart', '.go', '.js', '.ts', '.tsx', '.jsx', '.java', '.kt', '.swift', '.py'];
    return codeExtensions.some(ext => file.endsWith(ext));
  }

  async analyzeCodeChanges() {
    // 分析代码变化并提供文档更新建议
    console.log('Analyzing code changes for documentation impact...');
    
    // 这里可以添加更复杂的分析逻辑
    // 例如：识别新增功能、修改的API等
    
    // 暂时实现一个简单的建议生成
    if (!this.learningData.codeChangeSuggestions) {
      this.learningData.codeChangeSuggestions = [];
    }
    
    const suggestion = {
      timestamp: new Date().toISOString(),
      message: '代码发生变化，建议检查相关文档是否需要更新',
      action: '请检查并更新相关文档以反映代码变化'
    };
    
    this.learningData.codeChangeSuggestions.push(suggestion);
    
    // 限制建议数量，只保留最近10条
    if (this.learningData.codeChangeSuggestions.length > 10) {
      this.learningData.codeChangeSuggestions = this.learningData.codeChangeSuggestions.slice(-10);
    }
    
    this.saveLearningData();
  }

  async checkDocumentChanges() {
    const docsPath = path.join(__dirname, 'docs');
    if (!fs.existsSync(docsPath)) return;

    console.log('Checking for document changes...');
    const hasChanges = await this.detectDocumentChanges();
    
    if (hasChanges) {
      console.log('Document changes detected, updating index...');
      await this.parseDocs();
      console.log('Document index updated successfully');
    }
  }

  async detectDocumentChanges() {
    const docsPath = path.join(__dirname, 'docs');
    const currentState = this.getDocumentState(docsPath);
    
    // 保存当前状态到学习数据
    if (!this.learningData.documentState) {
      this.learningData.documentState = currentState;
      return false;
    }
    
    const oldState = this.learningData.documentState;
    const hasChanges = JSON.stringify(currentState) !== JSON.stringify(oldState);
    
    if (hasChanges) {
      this.learningData.documentState = currentState;
      this.saveLearningData();
    }
    
    return hasChanges;
  }

  getDocumentState(dir, basePath = '') {
    const state = {};
    try {
      const files = fs.readdirSync(dir);
      
      files.forEach(file => {
        const fullPath = path.join(dir, file);
        const relativePath = path.join(basePath, file);
        
        try {
          const stats = fs.statSync(fullPath);
          if (stats.isDirectory()) {
            state[file] = this.getDocumentState(fullPath, relativePath);
          } else if (file.endsWith('.md')) {
            state[file] = {
              mtime: stats.mtime.toISOString(),
              size: stats.size
            };
          }
        } catch (error) {
          console.error(`Error getting state for ${fullPath}:`, error);
        }
      });
    } catch (error) {
      console.error(`Error reading directory ${dir}:`, error);
    }
    
    return state;
  }

  async parseDocs() {
    const docsPath = path.join(__dirname, 'docs');
    if (fs.existsSync(docsPath)) {
      console.log('Parsing documentation files...');
      this.walkDirectory(docsPath);
      console.log(`Parsed ${Object.keys(this.docs).length} documentation files`);
    } else {
      console.warn('Docs directory not found');
    }
  }

  walkDirectory(dir, basePath = '') {
    const files = fs.readdirSync(dir);
    files.forEach(file => {
      const fullPath = path.join(dir, file);
      const relativePath = path.join(basePath, file);
      if (fs.statSync(fullPath).isDirectory()) {
        this.walkDirectory(fullPath, relativePath);
      } else if (file.endsWith('.md')) {
        try {
          const content = fs.readFileSync(fullPath, 'utf8');
          this.docs[relativePath] = {
            content,
            parsed: marked.parse(content),
            lastModified: fs.statSync(fullPath).mtime
          };
        } catch (error) {
          console.error(`Error parsing ${relativePath}:`, error);
        }
      }
    });
  }

  analyzeProjectStructure() {
    const projectRoot = path.join(__dirname, '../../..');
    console.log('Analyzing project structure...');
    this.projectStructure = this.getDirectoryStructure(projectRoot);
    console.log('Project structure analyzed successfully');
  }

  getDirectoryStructure(dir, maxDepth = 3, currentDepth = 0) {
    if (currentDepth >= maxDepth) return {};
    
    const structure = {};
    try {
      const files = fs.readdirSync(dir);
      
      files.forEach(file => {
        if (file.startsWith('.') || file === 'node_modules' || file === 'build' || file === 'dist') return;
        
        const fullPath = path.join(dir, file);
        try {
          if (fs.statSync(fullPath).isDirectory()) {
            structure[file] = this.getDirectoryStructure(fullPath, maxDepth, currentDepth + 1);
          } else {
            structure[file] = 'file';
          }
        } catch (error) {
          console.error(`Error accessing ${fullPath}:`, error);
        }
      });
    } catch (error) {
      console.error(`Error reading directory ${dir}:`, error);
    }
    
    return structure;
  }

  loadLearningData() {
    const learningDataPath = path.join(__dirname, 'learning-data.json');
    if (fs.existsSync(learningDataPath)) {
      try {
        const data = fs.readFileSync(learningDataPath, 'utf8');
        this.learningData = JSON.parse(data);
        console.log('Learning data loaded successfully');
      } catch (error) {
        console.error('Error loading learning data:', error);
        this.learningData = {};
      }
    } else {
      this.learningData = {};
      console.log('No learning data found, starting fresh');
    }
  }

  saveLearningData() {
    const learningDataPath = path.join(__dirname, 'learning-data.json');
    try {
      fs.writeFileSync(learningDataPath, JSON.stringify(this.learningData, null, 2));
      console.log('Learning data saved successfully');
    } catch (error) {
      console.error('Error saving learning data:', error);
    }
  }

  async processQuery(query) {
    console.log(`Processing query: ${query}`);
    
    try {
      // 分析查询意图
      const intent = this.analyzeIntent(query);
      
      // 学习用户查询模式
      this.learnFromQuery(query, intent);
      
      // 运行技能提升系统分析
      await this.enhancementSystem.runFullAnalysis();
      const suggestions = this.enhancementSystem.getSuggestions();
      
      // 根据意图处理
      let response;
      switch (intent) {
        case 'project_overview':
          response = this.getProjectOverview();
          break;
        case 'document_retrieval':
          response = this.retrieveDocuments(query);
          break;
        case 'code_analysis':
          response = this.analyzeCode(query);
          // 添加技能提升系统的建议
          if (suggestions.length > 0) {
            response.content += '\n\n## 技能提升建议\n';
            suggestions.forEach((suggestion, index) => {
              response.content += `${index + 1}. **${suggestion.type}**: ${suggestion.message}\n`;
              response.content += `   ${suggestion.details}\n`;
            });
          }
          break;
        case 'feature_implementation':
          response = this.getFeatureImplementation(query);
          break;
        case 'bug_fix':
          response = this.getBugFix(query);
          // 添加技能提升系统的建议
          if (suggestions.length > 0) {
            response.content += '\n\n## 技能提升建议\n';
            suggestions.forEach((suggestion, index) => {
              response.content += `${index + 1}. **${suggestion.type}**: ${suggestion.message}\n`;
              response.content += `   ${suggestion.details}\n`;
            });
          }
          break;
        default:
          response = this.getDefaultResponse();
      }
      
      // 保存学习数据
      this.saveLearningData();
      
      return response;
    } catch (error) {
      console.error('Error processing query:', error);
      return {
        type: 'error',
        content: '处理查询时发生错误，请稍后再试。'
      };
    }
  }

  analyzeIntent(query) {
    const lowerQuery = query.toLowerCase();
    
    if (lowerQuery.includes('项目') && (lowerQuery.includes('结构') || lowerQuery.includes('概览') || lowerQuery.includes('介绍'))) {
      return 'project_overview';
    } else if (lowerQuery.includes('文档') || lowerQuery.includes('如何') || lowerQuery.includes('指南')) {
      return 'document_retrieval';
    } else if (lowerQuery.includes('代码') || lowerQuery.includes('实现') || lowerQuery.includes('编写')) {
      return 'code_analysis';
    } else if (lowerQuery.includes('功能') && (lowerQuery.includes('添加') || lowerQuery.includes('实现'))) {
      return 'feature_implementation';
    } else if (lowerQuery.includes('bug') || lowerQuery.includes('错误') || lowerQuery.includes('修复')) {
      return 'bug_fix';
    }
    return 'default';
  }

  learnFromQuery(query, intent) {
    if (!this.learningData.queries) {
      this.learningData.queries = {};
    }
    
    if (!this.learningData.queries[intent]) {
      this.learningData.queries[intent] = [];
    }
    
    // 记录查询，避免重复
    if (!this.learningData.queries[intent].includes(query)) {
      this.learningData.queries[intent].push(query);
    }
    
    // 统计意图频率
    if (!this.learningData.intentFrequency) {
      this.learningData.intentFrequency = {};
    }
    
    this.learningData.intentFrequency[intent] = (this.learningData.intentFrequency[intent] || 0) + 1;
  }

  getProjectOverview() {
    return {
      type: 'project_overview',
      content: `# Moe Social 项目概览\n\nMoe Social是一个使用Flutter构建的可爱风格社交网络应用，旨在为用户提供现代化、直观且充满活力的社交体验。\n\n## 项目结构\n\n${this.formatProjectStructure(this.projectStructure)}\n\n## 主要功能\n- 用户认证系统（登录/注册）\n- 个人资料管理\n- 社交互动功能\n- 内容发现\n- 社区功能\n- 个性化功能\n- 娱乐功能\n- 实用功能\n\n## 技术栈\n- 前端：Flutter、Dart\n- 后端：Go、go-zero框架\n- 数据库：MySQL\n- 认证：JWT\n- RPC：gRPC`,
      structure: this.projectStructure
    };
  }

  formatProjectStructure(structure, indent = 0) {
    let result = '';
    const spaces = '  '.repeat(indent);
    
    for (const [key, value] of Object.entries(structure)) {
      if (value === 'file') {
        result += `${spaces}- ${key}\n`;
      } else {
        result += `${spaces}- ${key}/\n`;
        result += this.formatProjectStructure(value, indent + 1);
      }
    }
    
    return result;
  }

  retrieveDocuments(query) {
    const results = [];
    
    for (const [path, doc] of Object.entries(this.docs)) {
      if (doc.content.toLowerCase().includes(query.toLowerCase())) {
        results.push({
          path,
          content: doc.content.substring(0, 500) + '...',
          lastModified: doc.lastModified
        });
      }
    }
    
    if (results.length === 0) {
      return {
        type: 'document_retrieval',
        content: '未找到相关文档，请尝试使用不同的关键词。',
        results: []
      };
    }
    
    return {
      type: 'document_retrieval',
      content: `找到 ${results.length} 个相关文档：`,
      results
    };
  }

  analyzeCode(query) {
    // 简单的代码分析逻辑
    return {
      type: 'code_analysis',
      content: `# 代码分析\n\n针对查询 "${query}"，以下是相关的代码实现建议：\n\n1. **前端实现**：\n   - 检查 lib 目录下的相关模块\n   - 参考 docs/frontend 目录下的文档\n\n2. **后端实现**：\n   - 检查 backend 目录下的相关API和逻辑\n   - 参考 docs/backend 目录下的文档\n\n3. **最佳实践**：\n   - 遵循项目的代码风格规范\n   - 确保代码通过单元测试\n   - 考虑性能和安全性`
    };
  }

  getFeatureImplementation(query) {
    return {
      type: 'feature_implementation',
      content: `# 功能实现指南\n\n针对 "${query}"，以下是实现步骤：\n\n1. **需求分析**：\n   - 明确功能的具体需求\n   - 确定涉及的模块和组件\n\n2. **前端实现**：\n   - 创建或修改相关页面和组件\n   - 实现UI和交互逻辑\n   - 集成API调用\n\n3. **后端实现**：\n   - 设计API接口\n   - 实现业务逻辑\n   - 数据库操作\n\n4. **测试**：\n   - 单元测试\n   - 集成测试\n   - 端到端测试\n\n5. **部署**：\n   - 构建和发布\n   - 监控和优化`
    };
  }

  getBugFix(query) {
    return {
      type: 'bug_fix',
      content: `# Bug修复指南\n\n针对 "${query}"，以下是修复步骤：\n\n1. **问题分析**：\n   - 复现问题\n   - 分析错误日志\n   - 定位问题根源\n\n2. **修复方案**：\n   - 设计修复方案\n   - 实现修复代码\n   - 测试修复效果\n\n3. **回归测试**：\n   - 确保修复不会引入新问题\n   - 测试相关功能\n\n4. **文档记录**：\n   - 记录问题原因和解决方案\n   - 更新相关文档`
    };
  }

  getDefaultResponse() {
    return {
      type: 'default',
      content: '我是Moe Social项目的智能开发助手，有什么可以帮助您的吗？\n\n您可以询问以下类型的问题：\n- 项目结构和概览\n- 功能实现指南\n- 代码分析和建议\n- Bug修复方案\n- 相关文档查询'
    };
  }

  // 技能唤醒方法，用于判断是否应该触发技能
  shouldTrigger(query) {
    const lowerQuery = query.toLowerCase();
    
    // 检查是否包含与项目相关的关键词
    const projectKeywords = ['moe', 'social', '项目', '代码', '功能', 'bug', '修复', '文档', '实现'];
    
    // 检查是否包含与技能功能相关的关键词
    const skillKeywords = ['开发', '助手', '智能', '分析', '建议', '指南', '实现', '修复'];
    
    // 检查是否包含项目名称或相关术语
    const projectSpecificTerms = ['autoglm', 'flutter', 'go-zero', 'websocket', 'avatar', 'emoji'];
    
    // 计算匹配的关键词数量
    let matchCount = 0;
    
    projectKeywords.forEach(keyword => {
      if (lowerQuery.includes(keyword)) matchCount++;
    });
    
    skillKeywords.forEach(keyword => {
      if (lowerQuery.includes(keyword)) matchCount++;
    });
    
    projectSpecificTerms.forEach(term => {
      if (lowerQuery.includes(term)) matchCount++;
    });
    
    // 如果匹配的关键词数量大于等于2，或者包含项目名称，则触发技能
    return matchCount >= 2 || lowerQuery.includes('moe social') || lowerQuery.includes('moesocial');
  }
}

module.exports = MoeSkill;