/*
 * 这个文件：启动时加载 Sentinel 的限流和熔断规则（演示用）。
 */

package com.smartfridge.order;

import com.alibaba.csp.sentinel.slots.block.RuleConstant;
import com.alibaba.csp.sentinel.slots.block.degrade.DegradeRule;
import com.alibaba.csp.sentinel.slots.block.degrade.DegradeRuleManager;
import com.alibaba.csp.sentinel.slots.block.flow.FlowRule;
import com.alibaba.csp.sentinel.slots.block.flow.FlowRuleManager;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 启动时装载 Sentinel 规则。
 *
 * <p>规则写在代码里而不是只留在控制台，原因有两个：一是重启后规则不会丢，现场演示可复现；
 * 二是答辩时能直接指着这段代码说明“限的是哪个资源、阈值多少、触发后走哪个方法”。
 *
 * <p>两条规则分别对应两类保护：
 * <ul>
 *   <li>流控：{@code order-create} 的 QPS 上限，保护下单接口自身；</li>
 *   <li>熔断：{@code stock-deduct} 的慢调用比例，保护下单链路不被慢依赖拖垮。</li>
 * </ul>
 */
@Component
public class SentinelRules {

    private static final Logger log = LoggerFactory.getLogger(SentinelRules.class);

    private final int orderQps;
    private final int slowCallMillis;
    private final double slowRatio;

    public SentinelRules(
        @Value("${smart-fridge.sentinel.order-qps:2}") int orderQps,
        @Value("${smart-fridge.sentinel.slow-call-millis:500}") int slowCallMillis,
        @Value("${smart-fridge.sentinel.slow-ratio:0.5}") double slowRatio
    ) {
        this.orderQps = orderQps;
        this.slowCallMillis = slowCallMillis;
        this.slowRatio = slowRatio;
    }

    @PostConstruct
    public void load() {
        FlowRule flow = new FlowRule();
        flow.setResource("order-create");
        flow.setGrade(RuleConstant.FLOW_GRADE_QPS);
        flow.setCount(orderQps);
        flow.setControlBehavior(RuleConstant.CONTROL_BEHAVIOR_DEFAULT);
        FlowRuleManager.loadRules(List.of(flow));

        DegradeRule degrade = new DegradeRule();
        degrade.setResource("stock-deduct");
        // 慢调用比例：统计窗口内慢调用占比超过阈值即打开熔断
        degrade.setGrade(RuleConstant.DEGRADE_GRADE_RT);
        degrade.setCount(slowCallMillis);
        degrade.setSlowRatioThreshold(slowRatio);
        degrade.setMinRequestAmount(2);
        degrade.setStatIntervalMs(10_000);
        degrade.setTimeWindow(10);
        DegradeRuleManager.loadRules(List.of(degrade));

        log.info(
            "sentinel rules loaded: order-create QPS={} | stock-deduct slowCall>{}ms ratio>{} minRequest=2 window=10s",
            orderQps, slowCallMillis, slowRatio
        );
    }
}
