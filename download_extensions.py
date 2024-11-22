import requests
import os
import sys
import json
import zipfile
import shutil
import subprocess

def clean_removed_extensions(extensions_dir, config_extensions):
    """清理已删除的插件"""
    removed_count = 0
    for ext_dir in os.listdir(extensions_dir):
        ext_path = os.path.join(extensions_dir, ext_dir)
        if not os.path.isdir(ext_path) or ext_dir == 'temp':
            continue
        if ext_dir not in config_extensions:
            shutil.rmtree(ext_path)
            print(f"已删除未使用的插件: {ext_dir}")
            removed_count += 1
    return removed_count

def download_extension(name, ext_info, extensions_dir):
    try:
        temp_dir = os.path.join(extensions_dir, 'temp')
        final_dir = os.path.join(extensions_dir, name)
        os.makedirs(temp_dir, exist_ok=True)
        
        crx_path = os.path.join(temp_dir, f"{name}.crx")
        
        # 检查版本
        current_version_file = os.path.join(final_dir, '.version')
        current_version = None
        if os.path.exists(current_version_file):
            with open(current_version_file, 'r') as f:
                current_version = f.read().strip()
        
        # 版本相同则跳过
        if current_version == ext_info.get('version') and os.path.exists(final_dir):
            print(f"{ext_info['name']} 已是最新版本 {current_version}")
            return False
            
        print(f"下载 {ext_info['name']} 版本 {ext_info.get('version', '未知')}")
        response = requests.get(ext_info['url'], allow_redirects=True)
        
        if response.status_code == 200:
            with open(crx_path, 'wb') as f:
                f.write(response.content)
            
            try:
                if os.path.exists(final_dir):
                    shutil.rmtree(final_dir)
                    
                with zipfile.ZipFile(crx_path, 'r') as zip_ref:
                    zip_ref.extractall(final_dir)
                
                # 保存版本信息
                with open(current_version_file, 'w') as f:
                    f.write(ext_info.get('version', 'unknown'))
                
                print(f"{ext_info['name']} 更新成功")
                return True
            except Exception as e:
                print(f"解压失败: {str(e)}")
                return False
            finally:
                shutil.rmtree(temp_dir)
        else:
            print(f"下载失败: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"处理出错: {str(e)}")
        return False

def get_extension_paths(extensions_dir):
    """获取所有已安装扩展的路径"""
    paths = []
    for ext_dir in os.listdir(extensions_dir):
        if os.path.isdir(os.path.join(extensions_dir, ext_dir)) and ext_dir != 'temp':
            paths.append(f"/config/extensions/{ext_dir}")
    return paths

def restart_chrome_container():
    """重启Chrome容器并更新环境变量"""
    try:
        home_dir = os.path.expanduser('~')
        chromium_dir = os.path.join(home_dir, 'chromium')
        
        if os.path.exists(chromium_dir):
            subprocess.run(['docker', 'compose', '-f', f'{chromium_dir}/docker-compose.yaml', 'down'], check=True)
            subprocess.run(['docker', 'compose', '-f', f'{chromium_dir}/docker-compose.yaml', 'up', '-d'], check=True)
            print("Chrome容器已重启，新插件已生效")
            return True
        else:
            print(f"错误：找不到chromium目录 {chromium_dir}")
            return False
    except subprocess.CalledProcessError as e:
        print(f"重启Chrome容器失败: {e}")
        return False

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    extensions_dir = script_dir
    config_path = os.path.join(script_dir, 'extensions_config.json')
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"错误：找不到配置文件 {config_path}")
        return
    except json.JSONDecodeError:
        print("错误：配置文件格式不正确")
        return

    extensions = config.get('extensions', {})
    
    # 清理已删除的插件
    removed_count = clean_removed_extensions(extensions_dir, extensions)
    
    success_count = 0
    update_count = 0
    
    # 下载或更新插件
    for ext_id, ext_info in extensions.items():
        print(f"\n正在检查 {ext_info['name']}...")
        if download_extension(ext_id, ext_info, extensions_dir):
            success_count += 1
            update_count += 1
    
    # 更新Chrome启动参数
    extension_paths = get_extension_paths(extensions_dir)
    chrome_args = "--load-extension=" + ",".join(extension_paths)
    
    with open(os.path.join(script_dir, 'chrome_args.txt'), 'w') as f:
        f.write(chrome_args)

    print(f"\n检查完成：")
    print(f"总共检查了 {len(extensions)} 个扩展")
    print(f"成功处理 {success_count} 个")
    print(f"更新了 {update_count} 个")
    print(f"删除了 {removed_count} 个")
    print(f"Chrome启动参数已更新")

    # 只有在有更新或删除时才重启容器
    if update_count > 0 or removed_count > 0:
        print("\n正在重启Chrome以应用更改...")
        restart_chrome_container()

if __name__ == "__main__":
    main() 
