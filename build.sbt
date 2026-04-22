// SPDX-License-Identifier: Apache-2.0
// Foxden-risc-v — standalone Chisel/sbt build
//
// Vendored generator sources live under generators/ and rocket-chip/, all
// built with Chisel 3.6.1. No git submodules, no external fetches.

val chiselVersion = "3.6.1"

lazy val commonSettings = Seq(
  organization := "net.foxden",
  version := "1.0",
  scalaVersion := "2.13.10",
  parallelExecution in Global := false,
  scalacOptions ++= Seq("-deprecation", "-unchecked"),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full),
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  libraryDependencies ++= Seq("org.json4s" %% "json4s-jackson" % "4.0.5"))

// --- Root Foxden project ------------------------------------------------------

lazy val foxden = (project in file("."))
  .dependsOn(cde)
  .dependsOn(boom)
  .dependsOn(rocketchip)
  .dependsOn(sifive_cache)
  .settings(commonSettings)
  .settings(assemblyJarName in assembly := "foxden.jar")
  .settings(assemblyMergeStrategy in assembly := {
    case PathList("META-INF", xs @ _*) => MergeStrategy.discard
    case x => MergeStrategy.first
  })

// --- Vendored dependencies ---------------------------------------------------

lazy val hardfloat = (project in file("generators/rocket-chip/hardfloat"))
  .settings(commonSettings)

lazy val rocket_macros = (project in file("generators/rocket-chip/macros"))
  .settings(commonSettings)

lazy val rocketchip = (project in file("generators/rocket-chip"))
  .dependsOn(cde)
  .dependsOn(hardfloat)
  .dependsOn(rocket_macros)
  .settings(commonSettings)
  .settings(
    semanticdbEnabled := true,
    semanticdbVersion := scalafixSemanticdb.revision,
    scalacOptions += "-Ywarn-unused")
  .settings(libraryDependencies ++= Seq("com.lihaoyi" %% "mainargs" % "0.5.0"))

lazy val testchipip = (project in file("generators/testchipip"))
  .dependsOn(cde)
  .dependsOn(rocketchip)
  .settings(commonSettings)
  .settings(includeFilter in unmanagedSources := { "Util.scala" || "TraceIO.scala" || "Serdes.scala" })

lazy val boom = Project(id = "boom", base = file("generators/riscv-boom") / "src")
  .dependsOn(cde)
  .dependsOn(rocketchip)
  .dependsOn(testchipip)
  .settings(commonSettings)
  .settings(scalaSource in Compile := baseDirectory.value / "main/scala")

lazy val sifive_cache = (project in file("generators/sifive-cache"))
  .dependsOn(cde)
  .dependsOn(rocketchip)
  .settings(commonSettings)
  .settings(scalaSource in Compile := baseDirectory.value / "design/craft")

lazy val targetutils = (project in file("generators/targetutils"))
  .settings(commonSettings)

lazy val cde = (project in file("generators/rocket-chip/cde"))
  .settings(commonSettings)
  .settings(scalaSource in Compile := baseDirectory.value / "cde/src/chipsalliance/rocketchip")
