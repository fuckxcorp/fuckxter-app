<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wix="http://schemas.microsoft.com/wix/2006/wi"
  xmlns="http://schemas.microsoft.com/wix/2006/wi"
  exclude-result-prefixes="xsl wix">
  <xsl:output method="xml" indent="yes" />

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="wix:File[contains(@Source, 'fuckxter_app.exe')]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
      <Shortcut Id="ApplicationStartMenuShortcut"
                Name="FuckXter"
                Directory="ApplicationProgramsFolder"
                WorkingDirectory="INSTALLFOLDER"
                Advertise="yes" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="wix:Component[wix:File[contains(@Source, 'fuckxter_app.exe')]]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
      <RemoveFolder Id="RemoveApplicationProgramsFolder"
                    Directory="ApplicationProgramsFolder"
                    On="uninstall" />
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
