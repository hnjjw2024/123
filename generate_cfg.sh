#!/bin/bash

TEMPLATE="RAX3000M_XR30_cfg-telnet-20240117.conf"

if [ ! -f "$TEMPLATE" ]; then
    echo "模板文件 $TEMPLATE 不存在，请确认文件路径。"
    exit 1
fi

while IFS= read -r SN || [ -n "$SN" ]; do
    [ -z "$SN" ] && continue

    echo "处理 SN: $SN"

    # 根据 SN 生成密码
    mypassword=$(openssl passwd -1 -salt aV6dW8bD "$SN")
    echo "原始生成的密码: $mypassword"

    # 三级条件判断逻辑
    # 条件1：第13位是数字1-9时不处理
    if [[ "${mypassword:12:1}" =~ [1-9] ]]; then
        echo "条件1触发：第13位是数字1-9，直接进行eval处理"
    # 条件2：第13位是数字0时的特殊处理
    elif [[ "${mypassword:12:1}" == "0" ]]; then
        mypassword="\$'sh'${mypassword:13:34}"
        echo "条件2触发：第13位是数字0，添加sh前缀"
    # 条件3：超长字符串导致输出空密码无法解密
    elif [ ${#mypassword} -ge 34 ] && 
         ! grep -q '[^a-zA-Z0-9]' <<< "${mypassword:12}" && 
         [[ ! "${mypassword:12:1}" =~ [0-9] ]]; then
        mypassword=""
        echo "条件3触发：超长字符串处理后得到空密码，暂时无法解密"
    else
        echo "原始密码未包含特殊字符，直接进行eval处理"
    fi

    # eval处理（建议谨慎使用）
    if [ -n "$mypassword" ]; then
        mypassword=$(eval "echo $mypassword")
        echo "处理后得到的密码: $mypassword"
    fi

    # 原有替换逻辑
    if [[ "$mypassword" == *'generate_cfg.sh'* ]]; then
        mypassword="${mypassword//generate_cfg.sh/sh}"
        echo "特殊字符串已替换: $mypassword"
    fi

    # 加密模板文件
    if [ -n "$mypassword" ]; then
        if openssl aes-256-cbc -pbkdf2 -k "$mypassword" -in "$TEMPLATE" -out "cfg_${SN}.conf"; then
            echo "用密码 $mypassword 加密 cfg_${SN}.conf 成功。"
        else
            echo "用密码 $mypassword 加密 cfg_${SN}.conf 失败。"
        fi
    else
        echo "跳过加密：当前SN暂无法解密。"
    fi
    echo "-----------------------------------"
done < sn.txt