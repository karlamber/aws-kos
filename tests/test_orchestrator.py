from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from orchestrator.config import LandscapeConfig
from orchestrator.stacks import StackGraphError, build_graph, topo_sort


class TopoSortTests(unittest.TestCase):
    def test_full_order_respects_deps(self) -> None:
        graph = build_graph()
        ordered = topo_sort(graph, None)
        names = [s.name for s in ordered]
        self.assertLess(names.index("cloudwatch_logging"), names.index("vpc"))
        self.assertLess(names.index("vpc"), names.index("rds"))
        self.assertLess(names.index("rds"), names.index("lambda-argus_api"))
        self.assertLess(names.index("lambda-argus_api"), names.index("api-gateway"))
        self.assertLess(names.index("api-gateway"), names.index("cloudfront"))
        self.assertLess(names.index("tls"), names.index("cloudfront"))
        self.assertLess(names.index("cloudfront"), names.index("dns_record"))

    def test_selection_pulls_transitive_deps(self) -> None:
        graph = build_graph()
        ordered = topo_sort(graph, {"rds"})
        self.assertEqual([s.name for s in ordered], ["cloudwatch_logging", "vpc", "rds"])

    def test_unknown_stack(self) -> None:
        graph = build_graph()
        with self.assertRaises(StackGraphError):
            topo_sort(graph, {"nope"})


class ConfigRefreshTests(unittest.TestCase):
    def test_placeholder_tfvars_shape(self) -> None:
        cfg = LandscapeConfig(
            env="dev",
            account_name="aws-kos-dev",
            account_id="000000000000",
            aws_profile="aws-kos-dev",
            landscape="kos",
            region="us-east-1",
            region_short="ue1",
            route53_account_id="000000000000",
            dns_manager_role_arn="arn:aws:iam::000000000000:role/role-EXAMPLE-root-ue1-dns_manager",
            artifact_bucket="s3-EXAMPLE-mgmt-ue1-shared-lambda",
            oidc_subjects=("EXAMPLE_GITHUB_ORG/easycmdb-api:*",),
            account_dir=Path("/tmp"),
        )
        self.assertEqual(cfg.state_bucket, "s3-kos-dev-ue1-terraform-state")
        self.assertEqual(cfg.as_tfvars()["landscape"], "kos")


if __name__ == "__main__":
    unittest.main()
