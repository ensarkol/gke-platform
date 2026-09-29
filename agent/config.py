from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        case_sensitive=False,
        extra="ignore",
        populate_by_name=True,
    )

    project_id: str = Field(default="", validation_alias="PROJECT_ID")
    region: str = Field(default="europe-west1", validation_alias="REGION")
    zone: str = Field(default="europe-west1-b", validation_alias="ZONE")
    cluster_name: str = Field(default="test-gke", validation_alias="CLUSTER_NAME")
    gemini_model: str = Field(default="gemini-2.0-flash", validation_alias="GEMINI_MODEL")
    grafana_url: str = Field(
        default="http://kube-prometheus-stack-grafana.monitoring.svc",
        validation_alias="GRAFANA_URL",
    )
    grafana_token: str = Field(default="", validation_alias="GRAFANA_TOKEN")
    host: str = Field(default="0.0.0.0", validation_alias="HOST")
    port: int = Field(default=8080, validation_alias="PORT")


settings = Settings()
