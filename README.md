
---

# 🚀 Ultimate FFUF Scanner  
**Advanced Web Path Scanner with Slack Integration | Clean Reporting & Automated Filtering**  

![GitHub](https://img.shields.io/badge/Shell_Script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)  
*"Because manual fuzzing is so 2020."*  

---

## 📌 Key Features  
- **Structured Output**: Automatically organizes results by domain (e.g., `fuzzresults/apple.com/food.apple.com/`).  
- **Slack Alerts**: Sends filtered results (`clean_results.txt`) directly to your Slack channel.  
- **Noise Reduction**: Removes duplicate responses (configurable threshold).  
- **HTTPS/HTTP Fallback**: Auto-detects working protocol.  

---

## ⚙️ Prerequisites  
1. **Tools**:  
   - [`ffuf`](https://github.com/ffuf/ffuf) (`go install github.com/ffuf/ffuf/v2@latest`)  
   - `jq` (`apt install jq`)  
   - `curl`  

2. **Slack Setup**:  
   - Create a Slack incoming webhook ([guide](https://api.slack.com/messaging/webhooks)).  
   - Replace the placeholder in the script:  
     ```bash
     SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/PATH"
     ```

---

## 🛠️ Installation  
```bash
git clone https://github.com/Yaswanthsainani/ultimate-ffuf-scanner.git  
cd ultimate-ffuf-scanner  
chmod +x ffuf_scanner.sh  
```

---

## 🚀 Usage  
### Scan a Single Target  
```bash
./ffuf_scanner.sh  
Enter target (domain/IP) or path to domain list: food.apple.com  
```

### Scan Multiple Targets (File Input)  
```bash
echo "food.apple.com\nbeta.apple.com" > targets.txt  
./ffuf_scanner.sh  
Enter target (domain/IP) or path to domain list: targets.txt  
```

---

## 📂 Output Structure  
```bash
fuzzresults/  
└── apple.com/  
    ├── food.apple.com/  
    │   ├── food.apple.com.json    # Raw JSON results  
    │   ├── clean_results.txt     # Filtered endpoints (sent to Slack)  
    │   └── scan.log             # Full execution logs  
    └── beta.apple.com/  
        ├── beta.apple.com.json  
        ├── clean_results.txt  
        └── scan.log  
```

**Example `clean_results.txt`**:  
```
https://food.apple.com/admin [Status: 200, Size: 1234]  
https://food.apple.com/login [Status: 302, Size: 5678]  
```

---

## ⚡️ Customization  
Edit these variables in the script:  
```bash
WORDLIST="/path/to/wordlist.txt"       # Default: super.txt  
STATUS_CODES="200,302,403"            # Valid HTTP status codes  
MAX_DUPLICATE_SIZE=5                  # Filter >5 duplicate sizes  
```

---

## 📜 License  
MIT © [Yaswanth]  

---

## 💡 Pro Tips  
1. **Wordlist Recommendation**: Use [super.txt] https://github.com/kullaisec/superword.txt/blob/main/super.txt.  
2. **Cron Jobs**: Automate scans with:  
   ```bash
   0 2 * * * /path/to/ffuf_scanner.sh < targets.txt  
   ```
3. **Debugging**: Check `scan.log` for detailed errors.  

---

**Contributions welcome!** 🛠️  
*Star ⭐ if this saves you time!*  

---

### 🔗 GitHub Markdown Tips  
- Use badges from [shields.io](https://shields.io).  
- Add screenshots (e.g., Slack notifications) in a `/screenshots` folder.  
- Emojis make your README pop! ([List](https://gist.github.com/rxaviers/7360908))  

This README covers setup, usage, and customization—making it easy for others to deploy your tool. Adjust the placeholders (like `Yaswanth`) as needed!
