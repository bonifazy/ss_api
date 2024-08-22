from fastapi import FastAPI, Header
from fastapi.responses import JSONResponse
from passlib.context import CryptContext
from subprocess import Popen, PIPE
from pathlib import Path
from typing import Optional, Annotated
from uuid import uuid4
from base64 import b64encode
from json import loads, dumps
import yaml


# По умолчанию, файл находится в ~/ss_api/data/api_config.yml
# В файле находятся настройки сервера, пути до конфигурационных файлов подключенных vpn-протоколов
# и глобальных настроек этих протоколов для улучшения безопасности при REST-доступе к ним
YAML_FILE = 'data/api_config.yml'

# Универсальный ответ на ошибки при валидации запроса
json_response_unauthorized = JSONResponse({'401': 'Unauthorized'}, 401)
# Контекст хеширования данных из Headers и для Headers kot vpn bot
hash_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Следующие значения определяются здесь, но перезаписываются на актуальное значение при запуске main()
#
# Значение параметров из config.yml
SECRET = None
SUDO_PASS = None
HOST = None
XRAY_RESTART = ''
XRAY_CONFIG = ''
# Значения хеша для ответа боту
HASH_TO_BOT = None

# Открыть коннектор FastAPI. Может быть закрыт при старте программы при ошибке параметров в api_config.yml
app = FastAPI()


def config_is_correct() -> Optional[bool]:
    """
    Проверить корректность данных общих настроек Xray-сервера для валидации

    :return:
        True - данные корректны, FastAPI-сервер оставить запущенным;
        False - данные не корректны, проверить настройки в файле data/api_config.yml, остановить FastAPI-сервер;
        None - файл data/api_config.yml не найден, остановить FastAPI-сервер
    """

    # YAML_FILE: ~/ss_api/data/api_config.yml файл настроек SS-2022 сервера
    global YAML_FILE
    # Файл config.yml не найден
    if not Path(YAML_FILE).is_file():
        print(f'Файл {YAML_FILE} не найден.')
        return None

    # config.yml найден, проверить все предварительные настройки
    with open(YAML_FILE) as yaml_file:
        _yaml_data = yaml.safe_load(yaml_file)

    # Итог проверки системных настроек, изначально True. При ошибке входящих данных меняется на False
    is_correct_system = True
    # Параметр для верификации со входящими запросами. Обязательно синхронизировать с kot vpn bot
    _SECRET: str = _yaml_data.get('SECRET', None)
    # Параметр для доступа sudo: для перезагрузки vpn-сервера
    _SUDO_PASS: str = _yaml_data.get('SUDO_PASS', None)
    # Server hostname для отправки настроек ссылки ShadowSocks-2022
    _HOST: str = _yaml_data.get('HOST', None)
    # Не корректное значение какого-либо параметра
    if _SECRET is None or _SUDO_PASS is None or _HOST is None:
        print('Проверьте корректность параметров SECRET, SUDO_PASS или HOST в api_config.yml')
        is_correct_system = False

    # Изначально, выставить итог проверки в True. При ошибке получения какого-либо значения меняется на False
    is_correct_shell_paths = True
    _SS_RESTART: str = _yaml_data.get('SS_RESTART', None)
    # Не корректное значение XRAY_RESTART
    if (_SS_RESTART is not None and not Path(_SS_RESTART).is_file()) or _SS_RESTART is None:
        print('Проверьте корректность параметра SS_RESTART в api_config.yml')
        is_correct_shell_paths = False
    _SS_CONFIG: str = _yaml_data.get('SS_CONFIG', None)
    # Не корректное значение SS_CONFIG
    if (_SS_CONFIG is not None and not Path(_SS_CONFIG).is_file()) or _SS_CONFIG is None:
        print('Проверьте корректность параметра SS_CONFIG в api_config.yml')
        is_correct_shell_paths = False

    # Отправить результат проверки корректности параметров файла data/api_config.yml
    return True if is_correct_system and is_correct_shell_paths else False


def gen_hash(secret: str) -> Optional[dict]:
    """
    Токен для верификации с ботом kot vpn bot
    :param secret: параметр SECRET из config.py для хеширования
    :return: Заголовок Header: {Authorization: hash(secret)}
    """

    auth_hash = hash_context.hash(secret) if isinstance(secret, str) else ''
    return {'authorization': auth_hash}


def validate_request(authorization: Annotated[str | None, Header()] = None):
    f"""
    Проверка входящего запроса от хоста.
    Хостам, не проходящих валидацию "headers: Authorization" отправить {json_response_unauthorized}

    :param authorization: Header параметр Authorization, проверка запроса на подлинность
    :return: 
        True - верификация пройдена; 
        False - верификация отклонена
    """

    global SECRET
    if authorization is not None:
        try:
            if isinstance(authorization, str):
                authorization_bytes = authorization.encode('ascii')
                if isinstance(SECRET, str) and hash_context.verify(SECRET, authorization_bytes):
                    return True
        except ValueError:
            return False
    else:
        return False


@app.get("/link")
def get_link(authorization: str | None = Header(default=None)):

    # Ошибка валидации. Не достоверный хост или не корректный SECRET
    if not validate_request(authorization):
        return json_response_unauthorized

    # Открыть файл ~/ss/ss_config.json, распарсить, отправить настройки
    with open(SS_CONFIG) as json_file:
        ss_data = loads(json_file.read())
    inbound_list = [inbound for inbound in ss_data['inbounds'] if inbound['protocol'] == 'shadowsocks']
    inbound = inbound_list[0] if inbound_list else None

    # блок inbounds: {protocol: shadowsocks, ...} найден, вывести настройки
    if inbound is not None:
        _port = inbound['port']
        _method = inbound['settings']['method']
        _passwd = inbound['settings']['password']
        settings_line_bytes = f'{_method}:{_passwd}@{HOST}:{_port}'.encode('ascii')
        encoded_settings = b64encode(settings_line_bytes)[:-1].decode('ascii')
        content = {'settings': encoded_settings}

    # блок inbound.protocol == 'shadowsocks' не найден, нет клиентов
    else:
        content = {'settings': list()}

    return JSONResponse(content, 200, HASH_TO_BOT)


# Проверка подключения FastApi.
# Если есть ошибка в файле конфигурации data/api_config.yml, закрыть коннектор FastAPI, отправить предупреждение об ошибке
if config_is_correct():
    with open(YAML_FILE) as file:
        yaml_data = yaml.safe_load(file)

        # Загрузить актуальные значения параметров проекта
        SECRET = yaml_data.get('SECRET', None)
        SUDO_PASS = yaml_data.get('SUDO_PASS', None)
        HOST = yaml_data.get('HOST', None)
        SS_RESTART = yaml_data.get('SS_RESTART', '')
        SS_CONFIG = yaml_data.get('SS_CONFIG', '')
        HASH_TO_BOT = gen_hash(SECRET) if SECRET is not None else None

    print('\n**********\nsystemd ss_api.service запущен!')

else:
    del app
    print('\n**********\nsystemd ss_api.service не запущен!\nПроверьте корректность параметров в data/api_config.yml')
    exit()


if __name__ == '__main__':
    print(f'config_is_correct(): {config_is_correct()}')

