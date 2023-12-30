#!/bin/sh
#Customizable option area
wan_name="pppoe-wan"
trap_ports="21,22,23,3389"
trap6="no"
#Customizable option end

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin:/opt/sbin:$PATH"
IPREX4='([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])[/0-9]*'
IPREX6="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))[/0-9]*"

env_check() {
    if [ "$trap6" != "no" ]; then
        export v6="yes"
    else
        export v6="no"
    fi
    TEST=$(ipset help)
    if [ "$?" != "0" ]; then
        echo "Please install ipset."
        exit
    fi
    TEST=$(iptables -h)
    if [ "$?" != "0" ]; then
        echo "Please install iptables."
        exit
    fi
    TEST=$(ip6tables -h)
    if [ "$?" != "0" ]; then
        export v6="no"
        if [ "$trap6" = "yes" ]; then
            echo "trap6=yes but ip6tables not found."
        fi
    fi
}

creat_ipset() {
    if ipset list -n | grep -q flytrap_blacklist; then
        echo "flytrap ipset ipv4 has already been created."
    else
        echo Creating flytrap ipset ipv4...
        ipset create flytrap_blacklist hash:net
    fi
    if [ "$v6" != "no" ]; then
        if ipset list -n | grep -q flytrap6_blacklist; then
            echo "flytrap ipset ipv6 has already been created."
        else
            echo Creating flytrap ipset ipv6...
            ipset create flytrap6_blacklist hash:net family inet6
            if [ "$?" != "0" ]; then
                export v6="no"
            fi
        fi
    fi
}

clean_ipt() {
    rule_exp=$1
    rule_comment=$2
    rule_type=$3
    ipt_cmd="iptables"
    if [ "$rule_type" = "6" ]; then
        ipt_cmd="ip6tables"
    fi
    ipt_test=$($ipt_cmd -S | grep -E "$rule_exp" | head -1)
    if echo "$ipt_test" | grep -q "\-A"; then
        echo "Clean ""$rule_comment"" IPv""$rule_type"" ..."
        $ipt_cmd $(echo "$ipt_test" | sed "s/-A/-D/")
        ipt_test=$($ipt_cmd -S | grep -E "$rule_exp" | head -1)
        if echo "$ipt_test" | grep -q "\-A"; then
            clean_ipt "$rule_exp" "$rule_comment" "$rule_type"
        fi
    fi
}

clean_trap() {
    clean_ipt "INPUT.+""$wan_name"".+multiport.+flytrap_blacklist" "INPUT->flytrap_blacklist(ipset) IPv4" "4"
    clean_ipt "FORWARD.+""$wan_name"".+multiport.+flytrap_blacklist" "INPUT->flytrap_blacklist(ipset) IPv4" "4"
    clean_ipt "INPUT.+match-set.+flytrap_blacklist.+DROP" "flytrap_blacklist->INPUT(DROP) IPv4" "4"
    clean_ipt "FORWARD.+match-set.+flytrap_blacklist.+DROP" "flytrap_blacklist->FORWARD(DROP) IPv4" "4"
    clean_ipt "OUTPUT.+match-set.+flytrap_blacklist.+DROP" "flytrap_blacklist->OUTPUT(DROP) IPv4" "4"
    if [ "$v6" != "no" ]; then
        clean_ipt "INPUT.+""$wan_name"".+multiport.+flytrap6_blacklist" "INPUT->flytrap6_blacklist(ipset) IPv6" "6"
        clean_ipt "FORWARD.+""$wan_name"".+multiport.+flytrap6_blacklist" "INPUT->flytrap6_blacklist(ipset) IPv6" "6"
        clean_ipt "INPUT.+match-set.+flytrap6_blacklist.+DROP" "flytrap6_blacklist->INPUT(DROP) IPv6" "6"
        clean_ipt "FORWARD.+match-set.+flytrap6_blacklist.+DROP" "flytrap6_blacklist->FORWARD(DROP) IPv6" "6"
        clean_ipt "OUTPUT.+match-set.+flytrap6_blacklist.+DROP" "flytrap6_blacklist->OUTPUT(DROP) IPv6" "6"
    fi
}

add_trap() {
    echo "Add flytrap_blacklist rules..."
    iptables -I INPUT -m set --match-set flytrap_blacklist src -j DROP
    iptables -I FORWARD -m set --match-set flytrap_blacklist src -j DROP
    iptables -I OUTPUT -m set --match-set flytrap_blacklist src -j DROP
    iptables -I INPUT -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -j SET --add-set flytrap_blacklist src
    iptables -I FORWARD -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -j SET --add-set flytrap_blacklist src
    if [ "$v6" != "no" ]; then
        echo "Add flytrap6_blacklist rules..."
        ip6tables -I INPUT -m set --match-set flytrap6_blacklist src -j DROP
        ip6tables -I FORWARD -m set --match-set flytrap6_blacklist src -j DROP
        ip6tables -I OUTPUT -m set --match-set flytrap6_blacklist src -j DROP
        ip6tables -I INPUT -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -j SET --add-set flytrap6_blacklist src
        ip6tables -I FORWARD -i "$wan_name" -p tcp -m multiport --dports "$trap_ports" -j SET --add-set flytrap6_blacklist src
    fi
}

stripIP() {
    if [ "$2" = "6" ]; then
        echo "$1" | grep -Eo "$IPREX6"
    else
        echo "$1" | grep -Eo "$IPREX4"
    fi
    return $?
}

list_ips() {
    list_type=$1
    if [ "$list_type" = "6" ]; then
        if [ "$v6" != "no" ]; then
            stripIP "$(ipset list flytrap6_blacklist)" "6"
        fi
    else
        stripIP "$(ipset list flytrap_blacklist)" "4"
    fi
}

ip_opt() {
    opt=$1
    aip=$2
    testip=$(stripIP "$aip" "6")
    if [ "$?" = "0" ]; then
        if [ "$v6" != "no" ]; then
            if ipset list -n | grep -q flytrap6_blacklist; then
                ipset $opt flytrap6_blacklist "$testip"
                echo "$opt IPv6 ""$testip"
                return 0
            else
                echo "flytrap6_blacklist ipset not created."
            fi
        else
            echo "IPv6 not set."
        fi
        return 1
    fi
    testip=$(stripIP "$aip" "4")
    if [ "$?" = "0" ]; then
        if ipset list -n | grep -q flytrap_blacklist; then
            ipset $opt flytrap_blacklist "$testip"
            echo "$opt IPv4 ""$testip"
            return 0
        else
            echo "flytrap_blacklist ipset not created."
        fi
    else
        echo "Not a valid IP address."
    fi
    return 1
}

env_check

if [ "$1" = "clean" ]; then
    clean_trap
    exit
fi

if [ "$1" = "list" ]; then
    list_type=$2
    if [ -z "$list_type" ]; then
        list_type="4"
    fi
    list_ips "$list_type"
    exit
fi

if [ "$1" = "add" ]; then
    ip_opt add $2
    exit
fi

if [ "$1" = "del" ]; then
    ip_opt del $2
    exit
fi

if [ "$1" = "delall" ]; then
    if [ "$v6" != "no" ]; then
        if ipset list -n | grep -q flytrap6_blacklist; then
            ipset flush flytrap6_blacklist
        fi
    fi
    if ipset list -n | grep -q flytrap_blacklist; then
        ipset flush flytrap_blacklist
    fi
    exit
fi

date +"%Y-%m-%d %H:%M:%S %Z"
echo "wan_name=""$wan_name"
echo "trap_ports=""$trap_ports"
echo "trap6=""$trap6"
clean_trap
creat_ipset
add_trap

echo "Flytrap Deployment completed!"
