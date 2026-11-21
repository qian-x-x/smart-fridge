/*
 * 这个文件：创建工作区时的两道保护：QPS 限流 + 慢调用熔断；同时把 Seata 事务号透传给下游服务。
 */

package com.smartfridge.auth.workspace;

import com.alibaba.csp.sentinel.slots.block.RuleConstant;
import com.alibaba.csp.sentinel.slots.block.degrade.DegradeRule;
import com.alibaba.csp.sentinel.slots.block.degrade.DegradeRuleManager;
import com.alibaba.csp.sentinel.slots.block.flow.FlowRule;
import com.alibaba.csp.sentinel.slots.block.flow.FlowRuleManager;
import io.seata.core.context.RootContext;
import feign.RequestInterceptor;
import jakarta.annotation.PostConstruct;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class WorkspaceProtection {
    @Value("${smart-fridge.workspace.qps:5}") private double qps;
    @Value("${smart-fridge.workspace.slow-call-millis:1500}") private double slowMillis;
    @Value("${smart-fridge.workspace.circuit-min-requests:5}") private int minimum;

    @PostConstruct
    void rules() {
        var flow = new FlowRule("family-workspace-create");
        flow.setGrade(RuleConstant.FLOW_GRADE_QPS);
        flow.setCount(qps);
        FlowRuleManager.loadRules(List.of(flow));
        var circuit = new DegradeRule("family-fridge-initialize");
        circuit.setGrade(RuleConstant.DEGRADE_GRADE_RT);
        circuit.setCount(slowMillis);
        circuit.setSlowRatioThreshold(0.5);
        circuit.setMinRequestAmount(minimum);
        circuit.setStatIntervalMs(10000);
        circuit.setTimeWindow(10);
        DegradeRuleManager.loadRules(List.of(circuit));
    }

    @Bean
    RequestInterceptor workspaceXidPropagation() {
        return template -> {
            String xid = RootContext.getXID();
            if (xid != null) template.header(RootContext.KEY_XID, xid);
        };
    }
}
